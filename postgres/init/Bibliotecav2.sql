DROP SCHEMA IF EXISTS Biblioteca CASCADE;
CREATE SCHEMA Biblioteca;
SET search_path TO Biblioteca;

CREATE TABLE usuario (
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

CREATE TABLE cuenta (
    documento_usuario   varchar(10)     PRIMARY KEY  REFERENCES usuario(documento) ,
    contrasena          varchar(255)    NOT NULL ,
    tipo_usuario        varchar(20)     NOT NULL CHECK(tipo_usuario IN ('Lector','Bibliotecario','Administrador','Auditor'))
);

CREATE TABLE prestamo (
    id_prestamo         SERIAL        PRIMARY KEY,
    libro_prestado      varchar(13)   NOT NULL REFERENCES libro(isbn),
    documento_usuario   varchar(10)   NOT NULL REFERENCES usuario(documento),
    fecha_inicio        date          NOT NULL,
    fecha_limite        date          NOT NULL,
    devolucion          boolean       NOT NULL DEFAULT false , 
    CHECK (fecha_limite >= fecha_inicio)

);

-- ---------------------------------------------------------------
-- Tablas de paso (staging): todo es texto y nada tiene restricciones,
-- para que ninguna fila del archivo se pierda antes de revisarla.
-- Cada carga las vacía y las vuelve a llenar.
-- ---------------------------------------------------------------

-- Una fila por línea del archivo, sin partir en columnas
CREATE TABLE stg_linea (
    n      integer  GENERATED ALWAYS AS IDENTITY,  -- número de línea del archivo
    linea  text
);

CREATE TABLE stg_libro (
    isbn                    text,
    titulo                  text,
    autor                   text,
    categoria               text,
    anio_publicacion        integer,
    ejemplares_disponibles  integer,
    motivo                  text      -- NULL = la fila pasó la validación
);

CREATE TABLE stg_usuario (
    documento  text,
    nombres    text,
    apellidos  text,
    correo     text,
    telefono   text,
    motivo      text
);
