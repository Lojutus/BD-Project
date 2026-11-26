--sujeto de pruebas
INSERT INTO cuenta (documento, nombres, apellidos, correo, telefono) VALUES
('1000000001', 'Juan', 'Perez', 'juan@test.com', '3001111111');
-- Libro
INSERT INTO libro (isbn, titulo, autor, categoria, anio_publicacion) VALUES
('9781111111111', 'Cien Anos de Soledad', 'Gabriel Garcia Marquez', 'Ficcion', 1967);
--EJEMPLAR DISPONIBLE
INSERT INTO ejemplar (numero_ejemplar, isbn_libro, estado_ejemplar) VALUES
(1, '9781111111111', 10),
(2, '9781111111111', 10),
(3, '9781111111111', 10);
--Mora
INSERT INTO prestamo (numero_ejemplar, isbn_libro, documento_usuario, fecha_inicio, fecha_limite, fecha_devolucion) VALUES
(1, '9781111111111', '1000000001', CURRENT_DATE - 40, CURRENT_DATE - 30, NULL);
