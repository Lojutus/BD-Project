
\set ON_ERROR_STOP on
\if :{?archivo}
\else
    \set archivo /scripts/datos/lectores_propio.csv
\endif


CREATE EXTENSION IF NOT EXISTS pgcrypto;
SET search_path TO biblioteca, public;


BEGIN;

TRUNCATE stg_usuario, stg_linea RESTART IDENTITY;

-- 1. Leer el archivo tal cual: una fila por línea
COPY stg_linea (linea) FROM :'archivo' WITH (FORMAT text);
DELETE FROM stg_linea WHERE n = 1;          -- encabezado

-- 2. Partir cada línea en sus campos
INSERT INTO stg_usuario (linea_csv, contenido, num_campos,
                        documento, nombres, apellidos, correo, telefono)
SELECT n, linea,
       array_length(string_to_array(linea, ','), 1),
       trim(split_part(linea, ',', 1)),
       trim(split_part(linea, ',', 2)),
       trim(split_part(linea, ',', 3)),
       lower(trim(split_part(linea, ',', 4))),
       trim(split_part(linea, ',', 5))
FROM stg_linea;

-- 3. Validar (la primera regla que falla da el motivo)
UPDATE stg_usuario SET motivo = CASE
    WHEN num_campos <> 5                          THEN 'tiene ' || num_campos || ' columnas, se esperaban 5'
    WHEN documento = ''                           THEN 'documento vacío'
    WHEN documento !~ '^[0-9]{8,10}$'             THEN 'documento no numérico o de longitud inválida'
    WHEN nombres = ''                             THEN 'nombres vacío'
    WHEN apellidos = ''                           THEN 'apellidos vacío'
    WHEN correo = ''                              THEN 'correo vacío'
    WHEN correo !~ '^[^@ ]+@[^@ ]+\.[^@ ]+$'      THEN 'correo mal formado'
    WHEN telefono !~ '^[0-9]{7,10}$'              THEN 'teléfono no numérico o de longitud inválida'
    WHEN EXISTS (SELECT 1 FROM usuario l WHERE l.documento = stg_usuario.documento)
                                                  THEN 'documento ya existe'
    WHEN EXISTS (SELECT 1 FROM usuario l WHERE l.correo = stg_usuario.correo)
                                                  THEN 'correo ya registrado por otro lector'
END;

-- 4. Duplicados dentro del mismo archivo (por documento o por correo)
UPDATE stg_usuario SET motivo = 'documento o correo repetido en el archivo'
WHERE motivo IS NULL
  AND EXISTS (SELECT 1 FROM stg_usuario s2
              WHERE (s2.documento = stg_usuario.documento OR s2.correo = stg_usuario.correo)
                AND s2.motivo IS NULL
                AND s2.linea_csv < stg_usuario.linea_csv);

-- 5. Filas válidas a la tabla final
INSERT INTO usuario (documento, nombres, apellidos, correo, telefono)
SELECT documento, nombres, apellidos, correo, telefono
FROM stg_usuario
WHERE motivo IS NULL;

-- 5.1. La cuenta de cada lector cargado (contraseña inicial = documento, con hash)

INSERT INTO cuenta (documento_usuario, contrasena, tipo_usuario)
SELECT documento, crypt(documento, gen_salt('bf')), 'Lector'
FROM stg_usuario
WHERE motivo IS NULL;


-- 6. Rechazadas a la bitácora
INSERT INTO rechazo_carga (archivo, linea, contenido, motivo)
SELECT :'archivo', linea_csv, contenido, motivo
FROM stg_usuario
WHERE motivo IS NOT NULL;

COMMIT;

-- Resumen de la carga
SELECT count(*) FILTER (WHERE motivo IS NULL)     AS cargadas,
       count(*) FILTER (WHERE motivo IS NOT NULL) AS rechazadas
FROM stg_usuario;

SELECT linea_csv AS linea, motivo, contenido
FROM stg_usuario
WHERE motivo IS NOT NULL
ORDER BY linea_csv;
