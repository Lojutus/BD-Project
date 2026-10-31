SET search_path TO Biblioteca;

-- Reporte 1: cuenta todos los préstamos (abiertos y devueltos), 
-- incluye libros sin préstamos con 0 y conserva empates en el puesto 20 con WITH TIES.

SELECT l.titulo, count(pr.id_prestamo) AS num_prestamos
FROM libro l
LEFT JOIN prestamo pr ON pr.isbn_libro = l.isbn
GROUP BY l.isbn, l.titulo
ORDER BY num_prestamos DESC
FETCH FIRST 20 ROWS WITH TIES;

-- Reporte 2: solo cuentan los préstamos devueltos; empates incluidos; 
-- no une usuario porque el nombre está en cuenta.

WITH leidos AS (
    SELECT c.documento,
           c.nombres,
           c.apellidos,
           count(pr.id_prestamo) AS libros_leidos
    FROM cuenta c
    LEFT JOIN prestamo pr
           ON pr.documento_usuario = c.documento
          AND pr.fecha_devolucion IS NOT NULL
    GROUP BY c.documento, c.nombres, c.apellidos
)
SELECT documento, nombres, apellidos, libros_leidos
FROM leidos
WHERE libros_leidos = (SELECT max(libros_leidos) FROM leidos)
ORDER BY apellidos, nombres;
