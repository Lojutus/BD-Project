SET search_path TO Biblioteca;

-- 1. Insert Cuentas 
INSERT INTO cuenta (documento, nombres, apellidos, correo, telefono) VALUES
('1000000001', 'Juan', 'Perez', 'juan@test.com', '3001111111'),
('1000000002', 'Maria', 'Gomez', 'maria@test.com', '3002222222'),
('1000000003', 'Carlos', 'Lopez', 'carlos@test.com', '3003333333'),
('1000000004', 'Ana', 'Rios', 'ana@test.com', '3004444444'),
('1000000005', 'Luis', 'Torres', 'luis@test.com', '3005555555'),
('1000000006', 'Elena', 'Vargas', 'elena@test.com', '3006666666'),
('1000000007', 'Pedro', 'Mendoza', 'pedro@test.com', '3007777777');

-- 2. Insert Libros
INSERT INTO libro (isbn, titulo, autor, categoria, anio_publicacion, ejemplares_disponibles) VALUES
('9781111111111', 'Cien Anos de Soledad', 'Gabriel Garcia Marquez', 'Ficcion', 1967, 1),
('9782222222222', '1984', 'George Orwell', 'Ficcion', 1949, 1),
('9783333333333', 'Fahrenheit 451', 'Ray Bradbury', 'Ficcion', 1953, 1),
('9784444444444', 'El Hobbit', 'J.R.R. Tolkien', 'Fantasia', 1937, 3),
('9785555555555', 'Don Quijote de la Mancha', 'Miguel de Cervantes', 'Clasico', 1605, 3),
('9786666666666', 'Rayuela', 'Julio Cortazar', 'Ficcion', 1963, 4),
('9787777777777', 'Ficciones', 'Jorge Luis Borges', 'Ficcion', 1944, 4);

-- 3. Insert Ejemplares
INSERT INTO ejemplar (numero_ejemplar, isbn_libro, estado_ejemplar) VALUES
(1, '9781111111111', 10),
(1, '9782222222222', 10),
(1, '9783333333333', 10),
(1, '9784444444444', 10), (2, '9784444444444', 10), (3, '9784444444444', 10),
(1, '9785555555555', 10), (2, '9785555555555', 10), (3, '9785555555555', 10),
(1, '9786666666666', 10), (2, '9786666666666', 10), (3, '9786666666666', 10), (4, '9786666666666', 10),
(1, '9787777777777', 10), (2, '9787777777777', 10), (3, '9787777777777', 10), (4, '9787777777777', 10);

-- 4. Insert Prestamos 
INSERT INTO prestamo (numero_ejemplar, isbn_libro, documento_usuario, fecha_inicio, fecha_limite, fecha_devolucion) VALUES
(1, '9782222222222', '1000000001', CURRENT_DATE - 40, CURRENT_DATE - 30, CURRENT_DATE - 28),
(1, '9784444444444', '1000000001', CURRENT_DATE - 30, CURRENT_DATE - 20, CURRENT_DATE - 18),
(1, '9785555555555', '1000000001', CURRENT_DATE - 20, CURRENT_DATE - 10, CURRENT_DATE - 8),

(1, '9783333333333', '1000000002', CURRENT_DATE - 40, CURRENT_DATE - 30, CURRENT_DATE - 28),
(2, '9784444444444', '1000000002', CURRENT_DATE - 30, CURRENT_DATE - 20, CURRENT_DATE - 18),
(2, '9785555555555', '1000000002', CURRENT_DATE - 20, CURRENT_DATE - 10, CURRENT_DATE - 8),

(1, '9786666666666', '1000000003', CURRENT_DATE - 5, CURRENT_DATE + 5, NULL),
(2, '9786666666666', '1000000003', CURRENT_DATE - 5, CURRENT_DATE + 5, NULL),
(1, '9787777777777', '1000000003', CURRENT_DATE - 5, CURRENT_DATE + 5, NULL),
(2, '9787777777777', '1000000003', CURRENT_DATE - 5, CURRENT_DATE + 5, NULL),

(3, '9784444444444', '1000000004', CURRENT_DATE - 20, CURRENT_DATE - 10, CURRENT_DATE - 5),

(3, '9785555555555', '1000000005', CURRENT_DATE - 10, CURRENT_DATE, NULL),

(3, '9786666666666', '1000000006', CURRENT_DATE - 30, CURRENT_DATE - 15, NULL),
(3, '9787777777777', '1000000006', CURRENT_DATE - 20, CURRENT_DATE - 5, NULL);