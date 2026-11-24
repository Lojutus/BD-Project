DROP SCHEMA IF EXISTS Biblioteca CASCADE;
CREATE SCHEMA Biblioteca;
SET search_path TO Biblioteca;

CREATE TABLE cuenta (
    documento  varchar(10)   PRIMARY KEY CHECK (documento ~ '^[0-9]{8,10}$'),
    nombres    varchar(80)   NOT NULL CHECK (nombres <> ''),
    apellidos  varchar(80)   NOT NULL CHECK (apellidos <> ''),
    correo     varchar(120)  NOT NULL UNIQUE CHECK (correo ~ '^[^@ ]+@[^@ ]+\.[^@ ]+$'),
    telefono   varchar(10)   NOT NULL CHECK (telefono ~ '^[0-9]{10}$')
);

CREATE TABLE libro (
    isbn                    varchar(13)   PRIMARY KEY CHECK (isbn ~ '^[0-9]{13}$'),
    titulo                  varchar(200)  NOT NULL CHECK (titulo <> ''),
    autor                   varchar(120)  NOT NULL CHECK (autor <> ''),
    categoria               varchar(40)   NOT NULL CHECK (categoria <> ''),
    anio_publicacion        smallint      NOT NULL CHECK (anio_publicacion BETWEEN 1000 AND 2100),
    ejemplares_disponibles  smallint      NOT NULL DEFAULT 0 CHECK (ejemplares_disponibles >= 0)
);

CREATE TABLE ejemplar(
    numero_ejemplar     smallint        NOT NULL CHECK(numero_ejemplar > 0),
    isbn_libro          varchar(13)     REFERENCES libro(isbn),
    estado_ejemplar     smallint        NOT NULL CHECK(estado_ejemplar BETWEEN 1 AND 10) DEFAULT 10,
    PRIMARY KEY         (numero_ejemplar, isbn_libro) 
);

CREATE TABLE usuario (
    documento_usuario   varchar(10)   PRIMARY KEY  REFERENCES cuenta(documento) ,
    contrasena          varchar(255)  NOT NULL ,
    tipo_usuario        varchar(20)   NOT NULL CHECK(tipo_usuario IN ('Lector','Bibliotecario','Administrador','Auditor'))
);

CREATE TABLE prestamo (
    id_prestamo         SERIAL        PRIMARY KEY,
    numero_ejemplar     smallint      NOT NULL,
    isbn_libro          varchar(13)   NOT NULL,
    documento_usuario   varchar(10)   NOT NULL REFERENCES cuenta(documento),
    fecha_inicio        date          NOT NULL,
    fecha_limite        date          NOT NULL,
    fecha_devolucion    date          DEFAULT NULL,
    CHECK               (fecha_limite >= fecha_inicio AND (fecha_devolucion IS NULL OR fecha_devolucion >= fecha_inicio)),
    FOREIGN KEY         (numero_ejemplar, isbn_libro)  REFERENCES ejemplar(numero_ejemplar, isbn_libro)

  
);

CREATE UNIQUE INDEX idx_ejemplar_prestamo_activo 
ON prestamo (numero_ejemplar, isbn_libro) 
WHERE fecha_devolucion IS NULL;


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

-- copia deliberada de un dato derivado (ver documento de normalización, sección 5)
-- si devuelve filas, la copia se desincronizó del cálculo real
CREATE VIEW descuadre AS
SELECT l.isbn, l.titulo,
       l.ejemplares_disponibles AS guardado,
         (SELECT count(*) FROM ejemplar  e WHERE e.isbn_libro = l.isbn)
       - (SELECT count(*) FROM prestamo p
          WHERE p.isbn_libro = l.isbn AND p.fecha_devolucion IS NULL) AS calculado
FROM   libro l
WHERE  l.ejemplares_disponibles <>
         (SELECT count(*) FROM ejemplar  e WHERE e.isbn_libro = l.isbn)
       - (SELECT count(*) FROM prestamo p
          WHERE p.isbn_libro = l.isbn AND p.fecha_devolucion IS NULL);

CREATE MATERIALIZED VIEW top_prestados AS
SELECT l.isbn, l.titulo, count(pr.id_prestamo) AS num_prestamos
FROM   libro l
LEFT JOIN prestamo pr ON pr.isbn_libro = l.isbn
GROUP BY l.isbn, l.titulo
ORDER BY num_prestamos DESC
FETCH FIRST 20 ROWS WITH TIES;

CREATE MATERIALIZED VIEW top_lectores AS
WITH leidos AS (
    SELECT c.documento, c.nombres, c.apellidos, c.correo,
           count(pr.id_prestamo) AS libros_leidos
    FROM cuenta c
    LEFT JOIN prestamo pr ON pr.documento_usuario = c.documento
                          AND pr.fecha_devolucion IS NOT NULL
    GROUP BY c.documento, c.nombres, c.apellidos
)
SELECT documento, nombres, apellidos, correo, libros_leidos
FROM leidos
WHERE libros_leidos = (SELECT max(libros_leidos) FROM leidos)
ORDER BY apellidos, nombres;


