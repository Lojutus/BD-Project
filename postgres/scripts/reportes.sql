SET search_path TO Biblioteca;

-- reporte 1:
-- qué devuelve: los 20 libros más prestados.
-- decisiones: cuenta todos los préstamos (abiertos y devueltos), incluye libros con 0
--   y conserva empates en el puesto 20 (WITH TIES).
-- resultado esperado: 7 libros; cuatro con 3 préstamos, dos con 1 y Cien Años de Soledad con 0.

SELECT l.titulo, count(pr.id_prestamo) AS num_prestamos
FROM libro l
LEFT JOIN prestamo pr ON pr.isbn_libro = l.isbn
GROUP BY l.isbn, l.titulo
ORDER BY num_prestamos DESC
FETCH FIRST 20 ROWS WITH TIES;

-- reporte 2:
-- qué devuelve: el o los lectores que más libros han leído.
-- decisiones: solo préstamos devueltos, empates incluidos; el nombre está en cuenta.
-- resultado esperado: Juan Pérez y María Gómez, con 3 cada uno.

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
