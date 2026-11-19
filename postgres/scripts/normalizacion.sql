
-- ============================================================
-- NORMALIZACION - ESQUEMA BIBLIOTECA
-- ============================================================

SET search_path TO Biblioteca;


-- ============================================================
-- 1. EVIDENCIAS DE LOS CAMBIOS
-- ============================================================

-- CUENTA: Sin cambios.
-- EJEMPLAR: Sin cambios.
-- PRESTAMO: Sin cambios.
-- USUARIO: Sin cambios.


-- LIBRO:
-- Se identifica que ejemplares_disponibles es un dato derivado,
-- ya que puede calcularse contando los ejemplares y restando
-- aquellos que tienen un prestamo activo.
--
-- Actualmente, la columna almacena la cantidad total de
-- ejemplares y no la cantidad realmente disponible.
-- Por tanto, se trata de una redundancia de un dato derivado
-- que, ademas, presenta inconsistencias.


-- Consulta de evidencia:
-- Compara el valor almacenado con la cantidad real de
-- ejemplares disponibles.

SELECT
    l.isbn,
    l.ejemplares_disponibles AS valor_almacenado,
    COUNT(e.numero_ejemplar) AS disponibilidad_real
FROM libro l
LEFT JOIN ejemplar e
    ON e.isbn_libro = l.isbn
    AND NOT EXISTS (
        SELECT 1
        FROM prestamo p
        WHERE p.isbn_libro = e.isbn_libro
          AND p.numero_ejemplar = e.numero_ejemplar
          AND p.fecha_devolucion IS NULL
    )
GROUP BY
    l.isbn,
    l.ejemplares_disponibles
HAVING
    l.ejemplares_disponibles <> COUNT(e.numero_ejemplar);


-- ============================================================
-- 2. CORRECCIONES APLICADAS
-- ============================================================

BEGIN;


-- 2.1. Crear una vista para calcular dinamicamente
--      la cantidad de ejemplares disponibles por libro.

CREATE VIEW ejemplares_disponibles AS
SELECT
    l.isbn,
    l.titulo,
    COUNT(e.numero_ejemplar) - COUNT(p.numero_ejemplar)
        AS ejemplares_disponibles
FROM libro l
LEFT JOIN ejemplar e ON e.isbn_libro = l.isbn
LEFT JOIN prestamo p ON p.isbn_libro = e.isbn_libro
    AND p.numero_ejemplar = e.numero_ejemplar
    AND p.fecha_devolucion IS NULL
GROUP BY l.isbn, l.titulo
ORDER BY ejemplares_disponibles, l.isbn;


-- 2.2. Verificar los resultados de la vista  con datos-prueba.sql.
--     Se comparan los ejemplares disponibles obtenidos con los esperados.
--
--     ISBN             | Libro                      | Disponibles (Esperados)
--     9781111111111    | Cien Anos de Soledad       | 1
--     9782222222222    | 1984                       | 1
--     9783333333333    | Fahrenheit 451             | 1
--     9786666666666    | Rayuela                    | 1
--     9787777777777    | Ficciones                  | 1
--     9785555555555    | Don Quijote de la Mancha   | 2
--     9784444444444    | El Hobbit                  | 3

SELECT *
FROM ejemplares_disponibles;


-- 2.3. Eliminar la columna redundante de la tabla libro.
--      Su valor ahora se obtiene mediante la vista.

ALTER TABLE libro
DROP COLUMN ejemplares_disponibles;

--2.4. verificar que se mantiene el numero de registros con datos-prueba.sql
--     resultado esperado : 7 registros

SELECT COUNT(*) AS cantidad_libros
FROM libro;


-- ============================================================
-- 3. FINALIZAR LA TRANSACCION
-- ============================================================

COMMIT;


-- ============================================================
-- FIN DE LA NORMALIZACION
-- ============================================================
