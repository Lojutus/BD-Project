DROP SCHEMA IF EXISTS Biblioteca CASCADE;
CREATE SCHEMA Biblioteca;
SET search_path TO Biblioteca;

CREATE TABLE cuenta (
    documento  varchar(10)   PRIMARY KEY CHECK (documento ~ '^[0-9]{8,10}$'),
    nombres    varchar(80)   NOT NULL CHECK (nombres <> ''),
    apellidos  varchar(80)   NOT NULL CHECK (apellidos <> ''),
    correo     varchar(120)  NOT NULL UNIQUE CHECK (correo ~ '^[^@ ]+@[^@ ]+\.[^@ ]+$'),
    telefono   varchar(10)   NOT NULL CHECK (telefono ~ '^[0-9]{7,10}$')
);

CREATE TABLE libro (
    isbn                    varchar(13)   PRIMARY KEY CHECK (isbn ~ '^[0-9]{13}$'),
    titulo                  varchar(200)  NOT NULL CHECK (titulo <> ''),
    autor                   varchar(120)  NOT NULL CHECK (autor <> ''),
    categoria               varchar(40)   NOT NULL CHECK (categoria <> ''),
    anio_publicacion        smallint      NOT NULL CHECK (anio_publicacion BETWEEN 1000 AND 2100),
    ejemplares_disponibles  integer       NOT NULL CHECK (ejemplares_disponibles >= 0)
);

CREATE TABLE usuario (
    documento_usuario   varchar(10)     PRIMARY KEY  REFERENCES cuenta(documento) ,
    contrasena          varchar(255)    NOT NULL ,
    tipo_usuario        varchar(20)     NOT NULL CHECK(tipo_usuario IN ('Lector','Bibliotecario','Administrador','Auditor'))
);

CREATE TABLE prestamo (
    id_prestamo         SERIAL        PRIMARY KEY,
    libro_prestado      varchar(13)   NOT NULL REFERENCES libro(isbn),
    documento_usuario   varchar(10)   NOT NULL REFERENCES cuenta(documento),
    fecha_inicio        date          NOT NULL,
    fecha_limite        date          NOT NULL,
    fecha_devolucion    date          NULL,
    devolucion          boolean       NOT NULL DEFAULT false , 
    CHECK (fecha_limite >= fecha_inicio)

);
