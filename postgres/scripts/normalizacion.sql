
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
LEFT JOIN ejemplar e
    ON e.isbn_libro = l.isbn
LEFT JOIN prestamo p
    ON p.isbn_libro = e.isbn_libro
    AND p.numero_ejemplar = e.numero_ejemplar
    AND p.fecha_devolucion IS NULL
GROUP BY
    l.isbn,
    l.titulo;


-- 2.2. Verificar los resultados de la vista.

SELECT *
FROM ejemplares_disponibles;


-- 2.3. Eliminar la columna redundante de la tabla libro.
--      Su valor ahora se obtiene mediante la vista.

ALTER TABLE libro
DROP COLUMN ejemplares_disponibles;


-- ============================================================
-- 3. FINALIZAR LA TRANSACCION
-- ============================================================

COMMIT;


-- ============================================================
-- FIN DE LA NORMALIZACION
-- ============================================================
