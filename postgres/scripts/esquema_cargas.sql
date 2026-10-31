
-- ---------------------------------------------------------------
-- Tablas de paso (staging): todo es texto y nada tiene restricciones,
-- para que ninguna fila del archivo se pierda antes de revisarla.
-- Cada carga las vacía y las vuelve a llenar.
-- ---------------------------------------------------------------

SET search_path TO Biblioteca;

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
    anio_publicacion        text,
    ejemplares_disponibles  text,
    motivo                  text,      -- NULL = la fila pasó la validación
    linea_csv               integer,  -- número de línea del archivo
    contenido               text,      -- la línea completa del archivo  
    num_campos              integer   -- número de campos separados por coma
);

CREATE TABLE stg_cuenta (
    documento  text,
    nombres    text,
    apellidos  text,
    correo     text,
    telefono   text,
    motivo     text,
    linea_csv  integer,  -- número de línea del archivo
    contenido  text,      -- la línea completa del archivo
    num_campos integer   -- número de campos separados por coma
);

CREATE TABLE rechazo_carga (
    id        SERIAL PRIMARY KEY,
    archivo   text      NOT NULL,
    linea     integer   NOT NULL,
    contenido text      NOT NULL,
    motivo    text      NOT NULL,
    fecha     timestamp NOT NULL DEFAULT now()
);
