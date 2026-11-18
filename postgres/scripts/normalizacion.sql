SET search_path TO Biblioteca;
--EVIDENCIAS DE CAMBIOS 
--CUENTA: SIN CAMBIOS
--LIBRO: QUITAR LA COLUMNA Y CALCULARLA EN UNA VISTA QUIE RESTE LOS PRESTAMOS CON fecha_devolucion nula
SELECT isbn, ejemplares_disponibles AS dice, count(e.numero_ejemplar) AS reales
FROM libro l
LEFT JOIN ejemplar e ON e.isbn_libro = l.isbn
  AND NOT EXISTS (SELECT 1 FROM prestamo p WHERE p.isbn_libro = e.isbn_libro
                  AND p.numero_ejemplar = e.numero_ejemplar AND p.fecha_devolucion IS NULL)
GROUP BY isbn, ejemplares_disponibles
HAVING ejemplares_disponibles <> count(e.numero_ejemplar); 
--ejemplares_disponibles es un dato derivado que sale de contar lo ejemplares menos los prestamos activos y ademas esta mal calculado,
-- actualmente guarda la cantidad de ejemplares, no los disponibles; es una redundancia de dato derivado.

--EJEMPLAR: SIN CAMBIOS
--PRESTAMO: SIN CAMBIOS
--USUARIO: SIN CAMBIOS 


--CORRECCIONES 
BEGIN;

CREATE VIEW libro_disponibles AS
SELECT l.isbn, l.titulo, Count(e.numero_ejemplar) - Count(p.numero_ejemplar) AS ejemplares_disponibles
FROM libro l
LEFT JOIN ejemplar e ON e.isbn_libro = l.isbn
LEFT JOIN prestamo p ON p.isbn_libro = e.isbn_libro AND p.numero_ejemplar = e.numero_ejemplar AND p.fecha_devolucion IS NULL
GROUP BY l.isbn, l.titulo;

--COMO LA COLUMNA ejemplares_disponibles tenia un error , no tiene sentido usar un exept para comparar lo anterior con lo actual

-- Prueba de la vista libro_disponibles

SELECT * FROM libro_disponibles;

ALTER TABLE libro DROP COLUMN ejemplares_disponibles;
COMMIT;
