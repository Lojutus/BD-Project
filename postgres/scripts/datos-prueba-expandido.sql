-- datos de prueba masivos para el esquema Biblioteca.
-- se ejecuta después de init/biblioteca.sql, sobre una base vacía.
-- primero carga los datos base (datos-prueba.sql) y luego agrega:
--   2.000 cuentas (con su usuario), 5.000 libros, 15.000 ejemplares y 300.000 préstamos.
-- decisiones:
--   - no se usa random(): todo sale de fórmulas sobre generate_series, así cada ejecución
--     genera los mismos registros y las fechas siempre son relativas a CURRENT_DATE.
--   - 2.000 cuentas dan ~158 préstamos por lector en promedio sobre ~6,7 años de historia;
--     la asignación es sesgada (unos lectores piden mucho más que otros) y 100 cuentas no tienen préstamos.
--   - cada ejemplar tiene sus préstamos en ventanas de 35 días que no se solapan,
--     así nunca hay dos préstamos activos del mismo ejemplar (idx_ejemplar_prestamo_activo).
-- resultado esperado de reportes.sql con estos datos (base + masivos):
--   reporte 1: 21 libros, de "Libro de prueba 4001" (420) a 4020 y 4021 empatados con 306.
--   reporte 2: Bruno Acosta Herrera (2000000001) con 1.917 libros leídos.
--   reporte 3: 1.106 lectores con préstamos vencidos (incluye a Elena Vargas).
--   reporte 4: 1.432 filas (1.430 préstamos masivos en mora + los 2 de Elena Vargas).

\ir datos-prueba.sql

SET search_path TO Biblioteca;

-- 1. cuentas: documentos 2000000001 a 2000002000
INSERT INTO cuenta (documento, nombres, apellidos, correo, telefono)
SELECT '20' || lpad(i::text, 8, '0'),
       (ARRAY['Andrea','Bruno','Camila','Diego','Esteban','Fernanda','Gabriel','Helena','Ivan','Julia',
              'Kevin','Laura','Mateo','Natalia','Oscar','Paula','Ricardo','Sofia','Tomas','Valentina'])[1 + i % 20],
       (ARRAY['Acosta','Benitez','Castro','Diaz','Escobar','Franco','Garcia','Herrera','Ibarra','Jimenez',
              'Lozano','Morales','Navarro','Ortiz','Pineda','Quintero','Ramirez','Suarez','Trujillo','Uribe',
              'Valencia','Zapata','Rojas','Molina','Cardenas'])[1 + (i / 20) % 25]
       || ' ' ||
       (ARRAY['Acosta','Benitez','Castro','Diaz','Escobar','Franco','Garcia','Herrera','Ibarra','Jimenez',
              'Lozano','Morales','Navarro','Ortiz','Pineda','Quintero','Ramirez','Suarez','Trujillo','Uribe',
              'Valencia','Zapata','Rojas','Molina','Cardenas'])[1 + (i * 7) % 25],
       'lector' || i || '@test.com',
       '31' || lpad(i::text, 8, '0')
FROM generate_series(1, 2000) AS i;

-- 2. usuarios: uno por cuenta nueva, casi todos lectores
INSERT INTO usuario (documento_usuario, contrasena, tipo_usuario)
SELECT '20' || lpad(i::text, 8, '0'),
       md5('clave' || i),
       CASE WHEN i % 100 = 0 THEN 'Administrador'
            WHEN i % 50  = 0 THEN 'Auditor'
            WHEN i % 20  = 0 THEN 'Bibliotecario'
            ELSE 'Lector' END
FROM generate_series(1, 2000) AS i;

-- 3. libros: isbn 9790000000001 a 9790000005000
INSERT INTO libro (isbn, titulo, autor, categoria, anio_publicacion)
SELECT '979' || lpad(b::text, 10, '0'),
       'Libro de prueba ' || b,
       (ARRAY['Gabriel Garcia Marquez','Isabel Allende','Mario Vargas Llosa','Julio Cortazar','Jorge Luis Borges',
              'Pablo Neruda','Octavio Paz','Laura Restrepo','Hector Abad','Elena Poniatowska',
              'Carlos Fuentes','Juan Rulfo','Gabriela Mistral','Roberto Bolano','Alvaro Mutis',
              'Isaac Asimov','Ursula K. Le Guin','Agatha Christie','Stephen King','Jane Austen',
              'George Orwell','Ray Bradbury','J.R.R. Tolkien','Miguel de Cervantes','Franz Kafka',
              'Virginia Woolf','Albert Camus','Umberto Eco','Haruki Murakami','Toni Morrison'])[1 + b % 30],
       (ARRAY['Ficcion','Fantasia','Clasico','Ciencia Ficcion','Misterio',
              'Historia','Poesia','Ensayo','Biografia','Infantil'])[1 + b % 10],
       1900 + b % 125
FROM generate_series(1, 5000) AS b;

-- 4. ejemplares: 15.000 en total
--   libros    1-1000: 1 ejemplar   (1.000)
--   libros 1001-2000: 2 ejemplares (2.000)
--   libros 2001-4000: 3 ejemplares (6.000)
--   libros 4001-5000: 6 ejemplares (6.000)
INSERT INTO ejemplar (numero_ejemplar, isbn_libro, estado_ejemplar)
SELECT e,
       '979' || lpad(b::text, 10, '0'),
       10 - (b + e) % 5
FROM generate_series(1, 5000) AS b
CROSS JOIN LATERAL generate_series(1, CASE WHEN b <= 1000 THEN 1
                                           WHEN b <= 2000 THEN 2
                                           WHEN b <= 4000 THEN 3
                                           ELSE 6 END) AS e;

-- 5. préstamos: 300.000
-- escenarios:
--   - libros sin préstamos: 1-100 (1 ejemplar) y 4901-5000 (6 ejemplares).
--   - libros más prestados: 4001-4021, con 70 a 51 préstamos por ejemplar; 4020 y 4021 empatan
--     en el puesto 20 para probar el WITH TIES del reporte 1.
--   - el resto de los ejemplares tiene de 16 a 27 préstamos; se recortan los más antiguos
--     hasta completar exactamente 300.000.
--   - períodos de préstamo de 7, 14, 21 y 30 días; las devoluciones van de 3 días antes
--     a 3 días después de la fecha límite.
--   - el préstamo más reciente de cada ejemplar (s = 1) depende de c % 10:
--       0-5 devuelto, 6-7 activo al día, 8 activo y vencido, 9 activo que vence hoy (no cuenta como mora).
--   - los préstamos se reparten entre las cuentas 1-1900 con un sesgo (potencia 1,5) para que
--     unas tengan cerca de 2.000 préstamos y otras alrededor de 100; las cuentas 1901-2000 no tienen.
WITH copias AS (
    SELECT b, e, (row_number() OVER (ORDER BY b, e))::int AS c
    FROM generate_series(101, 4900) AS b
    CROSS JOIN LATERAL generate_series(1, CASE WHEN b <= 1000 THEN 1
                                               WHEN b <= 2000 THEN 2
                                               WHEN b <= 4000 THEN 3
                                               ELSE 6 END) AS e
),
mas_prestados AS (
    SELECT c, b, e, s
    FROM copias
    CROSS JOIN LATERAL generate_series(1, 70 - least(b - 4001, 19)) AS s
    WHERE b BETWEEN 4001 AND 4021
),
resto AS (
    SELECT c, b, e, s
    FROM copias
    CROSS JOIN LATERAL generate_series(1, 16 + c % 12) AS s
    WHERE b NOT BETWEEN 4001 AND 4021
    ORDER BY s, c
    LIMIT 300000 - (SELECT count(*) FROM mas_prestados)
),
numerados AS (
    SELECT c, b, e, s,
           row_number() OVER (ORDER BY c, s) AS n,
           (ARRAY[7, 14, 21, 30])[1 + (c + s) % 4] AS dur,
           CURRENT_DATE - 40 - (s - 1) * 35 AS ventana   -- inicio de la ventana de los préstamos antiguos
    FROM (SELECT * FROM mas_prestados UNION ALL SELECT * FROM resto) AS t
),
fechas AS (
    SELECT n, b, e, c, s, dur, ventana,
           CASE WHEN s > 1        THEN ventana + c % 3
                WHEN c % 10 <= 5  THEN CURRENT_DATE - 30
                WHEN c % 10 <= 7  THEN CURRENT_DATE - c % 7
                WHEN c % 10 = 8   THEN CURRENT_DATE - 40
                ELSE                   CURRENT_DATE - 14 END AS inicio
    FROM numerados
)
INSERT INTO prestamo (numero_ejemplar, isbn_libro, documento_usuario, fecha_inicio, fecha_limite, fecha_devolucion)
SELECT e,
       '979' || lpad(b::text, 10, '0'),
       '20' || lpad((1 + floor(1900 * power((((n - 1) * 7919) % 300000) / 300000.0, 1.5)))::int::text, 8, '0'),
       inicio,
       CASE WHEN s = 1 AND c % 10 IN (6, 7) THEN inicio + 14
            WHEN s = 1 AND c % 10 = 9       THEN CURRENT_DATE
            ELSE inicio + dur END,
       CASE WHEN s > 1       THEN least(inicio + dur + (c + s) % 7 - 3, ventana + 33)
            WHEN c % 10 <= 5 THEN least(inicio + dur - 3 + c % 6, CURRENT_DATE - 1)
            ELSE NULL END
FROM fechas
ORDER BY n;

-- recomputa la copia; en el Hito 4 lo hará un trigger
UPDATE libro l
SET    ejemplares_disponibles =
         (SELECT count(*) FROM ejemplar  e WHERE e.isbn_libro = l.isbn)
       - (SELECT count(*) FROM prestamo p
          WHERE p.isbn_libro = l.isbn AND p.fecha_devolucion IS NULL);

REFRESH MATERIALIZED VIEW top_prestados;