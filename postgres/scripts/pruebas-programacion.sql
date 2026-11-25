-- ============================================================================
-- BATERÍA DE PRUEBAS - PROGRAMACIÓN EN BASE DE DATOS (HITO 4)
-- ============================================================================
-- Requisitos previos:
--   1. Esquema creado con init/01_esquema.sql (biblioteca.sql).
--   2. Datos base cargados con scripts/datos-prueba.sql.
--   3. Objetos creados con scripts/programacion.sql.
--
-- Cómo ejecutar:
--   psql -U <usuario> -d <base> -f postgres/scripts/pruebas-programacion.sql
--   (NO usar ON_ERROR_STOP=1 porque varios casos prueban rechazos esperados).
-- ============================================================================

SET search_path TO Biblioteca;

-- ============================================================================
-- 0. VERIFICACIÓN BASE DE DESNORMALIZACIÓN (consulta de S20)
-- ============================================================================
-- Descripción: Comprueba que tras cargar datos-prueba.sql no existe ningún
-- descuadre en libro.ejemplares_disponibles antes de iniciar las pruebas.
-- Resultado esperado: 0 filas.
SELECT * FROM descuadre;


-- ============================================================================
-- 1. PRUEBAS DE FUNCIONES DE APOYO (José)
-- ============================================================================

-- 1.1 en_mora y prestamos_abiertos sobre todas las cuentas de datos-prueba.sql
-- Descripción: Verifica lectores sin préstamos (Pedro), con préstamos cerrados
-- (Juan, Maria, Ana), con varios abiertos al día (Carlos = 4), caso borde que
-- vence HOY sin mora (Luis) y lector con préstamos vencidos en mora (Elena).
-- Resultado esperado (7 filas):
--   1000000001 | Juan   | mora = f | abiertos = 0
--   1000000002 | Maria  | mora = f | abiertos = 0
--   1000000003 | Carlos | mora = f | abiertos = 4
--   1000000004 | Ana    | mora = f | abiertos = 0
--   1000000005 | Luis   | mora = f | abiertos = 1  (vence hoy -> NO está en mora)
--   1000000006 | Elena  | mora = t | abiertos = 2  (2 préstamos vencidos)
--   1000000007 | Pedro  | mora = f | abiertos = 0
SELECT documento,
       nombres,
       en_mora(documento)            AS mora,
       prestamos_abiertos(documento) AS abiertos
FROM   cuenta
ORDER BY documento;

-- 1.2 ejemplar_disponible sobre todos los libros y un ISBN inexistente
-- Descripción: Comprueba que retorna el menor ejemplar libre o NULL si no hay.
-- Resultado esperado:
--   9781111111111 Cien Anos de Soledad      -> 1
--   9782222222222 1984                      -> 1
--   9783333333333 Fahrenheit 451            -> 1
--   9784444444444 El Hobbit                 -> 1
--   9785555555555 Don Quijote de la Mancha  -> 1  (ejemplar 3 prestado a Luis)
--   9786666666666 Rayuela                   -> 4  (ejemplares 1, 2 y 3 prestados)
--   9787777777777 Ficciones                 -> 4  (ejemplares 1, 2 y 3 prestados)
SELECT isbn,
       titulo,
       ejemplar_disponible(isbn) AS ejemplar_libre
FROM   libro
ORDER BY isbn;

-- Caso borde: ISBN que no existe
-- Resultado esperado: 1 fila con ejemplar_libre = NULL.
SELECT ejemplar_disponible('9780000000000') AS ejemplar_libre;


-- ============================================================================
-- 2. PRUEBAS DEL PROCEDIMIENTO registrar_prestamo (José)
-- ============================================================================

-- 2.1 [DEBE FALLAR] Cuenta inexistente
-- Resultado esperado: ERROR indicando que la cuenta 9999999999 no existe.
BEGIN;
CALL registrar_prestamo('9999999999', '9784444444444');
ROLLBACK;

-- 2.2 [DEBE FALLAR] Libro inexistente
-- Resultado esperado: ERROR indicando que el libro 9780000000000 no existe.
BEGIN;
CALL registrar_prestamo('1000000007', '9780000000000');
ROLLBACK;

-- 2.3 [DEBE FALLAR] Regla de mora: Elena tiene 2 préstamos vencidos
-- Resultado esperado: ERROR indicando que la cuenta 1000000006 está en mora.
BEGIN;
CALL registrar_prestamo('1000000006', '9784444444444');
ROLLBACK;

-- 2.4 [DEBE PASAR] Préstamo limpio: Pedro pide El Hobbit (disponibles 3 -> 2)
-- Resultado esperado:
--   - Antes: descuadre = 0 filas; El Hobbit tiene ejemplares_disponibles = 3.
--   - CALL: NOTICE confirmando préstamo del ejemplar 1.
--   - Después: El Hobbit tiene ejemplares_disponibles = 2; descuadre = 0 filas.
BEGIN;
SELECT * FROM descuadre;                                                      -- 0 filas
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9784444444444';  -- 3
CALL registrar_prestamo('1000000007', '9784444444444');                       -- NOTICE: ejemplar 1
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9784444444444';  -- 2
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 2.5 [DEBE PASAR - CASO BORDE] Luis vence HOY (no está en mora), puede pedir
-- Resultado esperado:
--   - CALL: NOTICE confirmando préstamo del ejemplar 1 de El Hobbit.
--   - Después: El Hobbit baja de 3 a 2; descuadre = 0 filas.
BEGIN;
CALL registrar_prestamo('1000000005', '9784444444444');                       -- NOTICE: OK
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9784444444444';  -- 2
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 2.6 [DEBE PASAR - SIN LÍMITE DE 3] Carlos tiene 4 abiertos al día y pide un 5to
-- Descripción: Confirma que no hay restricción de máximo 3 préstamos abiertos.
-- Resultado esperado:
--   - CALL: NOTICE confirmando préstamo del ejemplar 1 de El Hobbit.
--   - prestamos_abiertos('1000000003') = 5; descuadre = 0 filas.
BEGIN;
CALL registrar_prestamo('1000000003', '9784444444444');                       -- NOTICE: OK
SELECT prestamos_abiertos('1000000003') AS abiertos_carlos;                   -- 5
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 2.7 [DEBE FALLAR] Libro sin ejemplares disponibles (Cien Anos solo tiene 1)
-- Descripción: Pedro toma el único ejemplar; luego Juan intenta pedir el mismo.
-- Resultado esperado:
--   - Primer CALL: NOTICE OK, ejemplares_disponibles pasa de 1 a 0,
--     ejemplar_disponible('9781111111111') retorna NULL.
--   - Segundo CALL: ERROR indicando que no hay ejemplares disponibles.
BEGIN;
CALL registrar_prestamo('1000000007', '9781111111111');                       -- OK (1 -> 0)
SELECT ejemplares_disponibles, ejemplar_disponible(isbn) AS libre
FROM   libro WHERE isbn = '9781111111111';                                    -- 0 | NULL
CALL registrar_prestamo('1000000001', '9781111111111');                       -- ERROR: sin ejemplares
ROLLBACK;


-- ============================================================================
-- 3. PRUEBAS DEL PROCEDIMIENTO registrar_devolucion (Miguel)
-- ============================================================================

-- 3.1 [DEBE FALLAR] Préstamo inexistente
-- Resultado esperado: ERROR indicando que el préstamo 99999 no existe o ya fue devuelto.
BEGIN;
CALL registrar_devolucion(99999);
ROLLBACK;

-- 3.2 [DEBE FALLAR] Préstamo ya devuelto (id_prestamo = 1, Juan)
-- Resultado esperado: ERROR indicando que el préstamo 1 no existe o ya fue devuelto.
BEGIN;
CALL registrar_devolucion(1);
ROLLBACK;

-- 3.3 [DEBE PASAR] Devolución de préstamo abierto (id 12: Luis devuelve Don Quijote)
-- Resultado esperado:
--   - Antes: descuadre = 0 filas; Don Quijote tiene ejemplares_disponibles = 2.
--   - CALL: NOTICE confirmando devolución del préstamo 12.
--   - Después: fecha_devolucion = CURRENT_DATE; Don Quijote sube a 3; descuadre = 0 filas.
BEGIN;
SELECT * FROM descuadre;                                                      -- 0 filas
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9785555555555';  -- 2
CALL registrar_devolucion(12);                                                -- NOTICE: OK
SELECT id_prestamo, fecha_devolucion FROM prestamo WHERE id_prestamo = 12;    -- 12 | HOY
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9785555555555';  -- 3
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 3.4 [DEBE PASAR - FLUJO COMPLETO] Elena devuelve sus 2 vencidos (13 y 14) y sale de mora
-- Resultado esperado:
--   - Tras devolver id 13 (Rayuela 1 -> 2): en_mora('1000000006') sigue en t.
--   - Tras devolver id 14 (Ficciones 1 -> 2): en_mora('1000000006') pasa a f.
--   - Luego Elena puede pedir El Hobbit (3 -> 2) y descuadre = 0 filas.
BEGIN;
CALL registrar_devolucion(13);                                                -- OK (Rayuela 1 -> 2)
SELECT en_mora('1000000006') AS sigue_en_mora;                                -- t
CALL registrar_devolucion(14);                                                -- OK (Ficciones 1 -> 2)
SELECT en_mora('1000000006') AS sigue_en_mora;                                -- f
CALL registrar_prestamo('1000000006', '9784444444444');                       -- OK (Hobbit 3 -> 2)
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;


-- ============================================================================
-- 4. PRUEBAS DEL TRIGGER BEFORE INSERT: prestamo_validar (Carlos)
-- ============================================================================

-- 4.1 [DEBE FALLAR] INSERT directo para cuenta en mora (Elena)
-- Descripción: Aunque se salte el procedimiento, el trigger bloquea el préstamo.
-- Resultado esperado: ERROR indicando que la cuenta 1000000006 está en mora.
BEGIN;
INSERT INTO prestamo (numero_ejemplar, isbn_libro, documento_usuario, fecha_inicio, fecha_limite)
VALUES (1, '9784444444444', '1000000006', CURRENT_DATE, CURRENT_DATE + 14);
ROLLBACK;

-- 4.2 [DEBE PASAR - CASO BORDE] INSERT directo para Luis (vence hoy, sin mora)
-- Resultado esperado: INSERT 0 1; descuadre = 0 filas.
BEGIN;
INSERT INTO prestamo (numero_ejemplar, isbn_libro, documento_usuario, fecha_inicio, fecha_limite)
VALUES (1, '9784444444444', '1000000005', CURRENT_DATE, CURRENT_DATE + 14);
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 4.3 [DEBE PASAR] INSERT histórico (ya devuelto) para cuenta en mora (Elena)
-- Descripción: Un préstamo que entra ya cerrado (fecha_devolucion IS NOT NULL)
-- no debe bloquearse por mora ni alterar ejemplares_disponibles.
-- Resultado esperado: INSERT 0 1; El Hobbit se mantiene en 3; descuadre = 0 filas.
BEGIN;
INSERT INTO prestamo (numero_ejemplar, isbn_libro, documento_usuario, fecha_inicio, fecha_limite, fecha_devolucion)
VALUES (1, '9784444444444', '1000000006', CURRENT_DATE - 30, CURRENT_DATE - 20, CURRENT_DATE - 18);
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9784444444444';  -- 3
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 4.4 [DEBE PASAR] INSERT sin fecha_inicio ni fecha_limite (valores por defecto)
-- Descripción: El trigger completa fecha_inicio = HOY y fecha_limite = HOY + 14.
-- Resultado esperado: 1 fila con fecha_inicio = CURRENT_DATE y
-- fecha_limite = CURRENT_DATE + 14 (diferencia = 14).
BEGIN;
INSERT INTO prestamo (numero_ejemplar, isbn_libro, documento_usuario)
VALUES (1, '9784444444444', '1000000007')
RETURNING id_prestamo, fecha_inicio, fecha_limite, (fecha_limite - fecha_inicio) AS dias_plazo;
ROLLBACK;


-- ============================================================================
-- 5. PRUEBAS DE TRIGGERS AFTER: prestamo_disponibles y ejemplar_disponibles (Carlos)
--    (Incluyen consulta de verificación descuadre de S20 antes y después)
-- ============================================================================

-- 5.1 [DEBE PASAR] INSERT directo en prestamo decrementa ejemplares_disponibles
-- Resultado esperado:
--   - Antes: descuadre = 0 filas; El Hobbit = 3.
--   - Después: El Hobbit = 2; descuadre = 0 filas.
BEGIN;
SELECT * FROM descuadre;                                                      -- 0 filas
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9784444444444';  -- 3
INSERT INTO prestamo (numero_ejemplar, isbn_libro, documento_usuario)
VALUES (1, '9784444444444', '1000000007');
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9784444444444';  -- 2
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 5.2 [DEBE PASAR] UPDATE reabriendo préstamo (fecha_devolucion -> NULL)
-- Descripción: En id 1 (1984, Juan) se anula la devolución.
-- Resultado esperado:
--   - Antes: descuadre = 0 filas; 1984 = 1.
--   - Después: 1984 = 0; descuadre = 0 filas.
BEGIN;
SELECT * FROM descuadre;                                                      -- 0 filas
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9782222222222';  -- 1
UPDATE prestamo SET fecha_devolucion = NULL WHERE id_prestamo = 1;
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9782222222222';  -- 0
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 5.3 [DEBE PASAR] DELETE de préstamo abierto libera el ejemplar
-- Descripción: Se elimina id 12 (Don Quijote, Luis).
-- Resultado esperado:
--   - Antes: descuadre = 0 filas; Don Quijote = 2.
--   - Después: Don Quijote = 3; descuadre = 0 filas.
BEGIN;
SELECT * FROM descuadre;                                                      -- 0 filas
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9785555555555';  -- 2
DELETE FROM prestamo WHERE id_prestamo = 12;
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9785555555555';  -- 3
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 5.4 [DEBE PASAR] UPDATE cambiando el libro de un préstamo abierto (id 12)
-- Descripción: Se reasigna id 12 de Don Quijote a El Hobbit ejemplar 1.
-- Ambos libros deben recalcularse.
-- Resultado esperado:
--   - Antes: descuadre = 0 filas; El Hobbit = 3, Don Quijote = 2.
--   - Después: El Hobbit = 2, Don Quijote = 3; descuadre = 0 filas.
BEGIN;
SELECT * FROM descuadre;                                                      -- 0 filas
SELECT isbn, ejemplares_disponibles FROM libro
WHERE  isbn IN ('9784444444444', '9785555555555')
ORDER BY isbn;                                                                -- Hobbit 3 | Quijote 2
UPDATE prestamo
SET    numero_ejemplar = 1, isbn_libro = '9784444444444'
WHERE  id_prestamo = 12;
SELECT isbn, ejemplares_disponibles FROM libro
WHERE  isbn IN ('9784444444444', '9785555555555')
ORDER BY isbn;                                                                -- Hobbit 2 | Quijote 3
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;

-- 5.5 [DEBE PASAR] INSERT y DELETE en tabla ejemplar actualiza ejemplares_disponibles
-- Descripción: Se agrega un segundo ejemplar físico de Cien Anos y luego se borra.
-- Resultado esperado:
--   - Antes: descuadre = 0 filas; Cien Anos = 1.
--   - Tras INSERT ejemplar 2: Cien Anos = 2; descuadre = 0 filas.
--   - Tras DELETE ejemplar 2: Cien Anos = 1; descuadre = 0 filas.
BEGIN;
SELECT * FROM descuadre;                                                      -- 0 filas
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9781111111111';  -- 1
INSERT INTO ejemplar (numero_ejemplar, isbn_libro, estado_ejemplar)
VALUES (2, '9781111111111', 10);
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9781111111111';  -- 2
SELECT * FROM descuadre;                                                      -- 0 filas
DELETE FROM ejemplar WHERE numero_ejemplar = 2 AND isbn_libro = '9781111111111';
SELECT isbn, ejemplares_disponibles FROM libro WHERE isbn = '9781111111111';  -- 1
SELECT * FROM descuadre;                                                      -- 0 filas
ROLLBACK;