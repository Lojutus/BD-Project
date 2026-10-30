# S14 — Carga de lectores desde CSV

**Esquema:** `biblioteca` (definido en `postgres/init/biblioteca-v2.sql`)
**Script:** `carga-lectores.sql`
**CSV propio:** `lectores_propio.csv`
**Integrante:** Carlos Andrés Meneses Llanten — 2516714

Decisiones de carga documentadas:

- La contraseña inicial de cada lector es su número de documento, guardada con hash
  bccrypt mediante `pgcrypto` (`crypt(documento, gen_salt('bf'))`). No en texto plano segun la sugerencia.
- Todo lector que entra por esta carga queda con `tipo_cuenta = 'Lector'`.
- Las filas inválidas no se insertan: se registran en `rechazo_carga` con archivo,
  línea, contenido original y motivo, para poder corregirlas y volver a cargarlas.

---

## 1. Lectores semilla sin errores

```bash
docker compose exec -T postgres psql -U biblioteca -d biblioteca \
  -v ON_ERROR_STOP=1 -v archivo=/scripts/datos/lectores_semilla.csv \
  -f /scripts/carga-lectores.sql
```

Resultado esperado: 20 cargadas, 0 rechazadas.

```text
CREATE EXTENSION
SET
BEGIN
TRUNCATE TABLE
COPY 21
DELETE 1
INSERT 0 20
UPDATE 20
UPDATE 0
INSERT 0 20
INSERT 0 20
INSERT 0 0
COMMIT
 cargadas | rechazadas 
----------+------------
       20 |          0
(1 row)

 linea | motivo | contenido 
-------+--------+-----------
(0 rows)
```

Las 20 filas entraron a `cuenta` y a `cuenta`, y la bitácora quedó vacía, entonces el archivo
no traía ningún error.

## 2. Lectores semilla con errores

```bash
docker compose exec -T postgres psql -U biblioteca -d biblioteca \
  -v ON_ERROR_STOP=1 -v archivo=/scripts/datos/lectores_semilla_con_errores.csv \
  -f /scripts/carga-lectores.sql
```

Resultado esperado: 0 cargadas, 6 rechazadas — una por cada tipo de error del archivo.

```text
CREATE EXTENSION
SET
psql:/scripts/carga-lectores.sql:9: NOTICE:  extension "pgcrypto" already exists, skipping
BEGIN
TRUNCATE TABLE
COPY 7
DELETE 1
INSERT 0 6
UPDATE 6
UPDATE 0
INSERT 0 0
INSERT 0 0
INSERT 0 6
COMMIT
 cargadas | rechazadas 
----------+------------
        0 |          6
(1 row)

 linea |                   motivo                    |                                         contenido                                         
-------+---------------------------------------------+-------------------------------------------------------------------------------------------
     2 | documento ya existe                         | 1000000001,Mariana,Gómez Rojas (duplicado),mariana.gomez@correo-ejemplo.edu.co,3001000001
     3 | correo vacío                                | 1000000021,Carlos,Peña Londoño,,3001000021
     4 | correo mal formado                          | 1000000022,Diana,Salgado Cuervo,diana.salgado-arroba-correo-ejemplo.edu.co,3001000022
     5 | teléfono no numérico o de longitud inválida | 1000000023,Jorge,Restrepo Vélez,jorge.restrepo@correo-ejemplo.edu.co,tres-cero-cero
     6 | documento vacío                             | ,Sin Documento,Prueba Prueba,sin.documento@correo-ejemplo.edu.co,3001000024
     7 | nombres vacío                               | 1000000025,,Sin Nombre,sin.nombre@correo-ejemplo.edu.co,3001000025
(6 rows)
```

Los seis tipos de error del archivo quedaron atrapados y registrados con su motivo:

| Línea | Error | Motivo registrado |
|---|---|---|
| 2 | documento ya cargado en la corrida 1 | documento ya existe |
| 3 | correo vacío | correo vacío |
| 4 | correo sin @ | correo mal formado |
| 5 | teléfono con letras | teléfono no numérico o de longitud inválida |
| 6 | documento vacío | documento vacío |
| 7 | nombres vacío | nombres vacío |

## 3. CSV propio (`lectores_propio.csv`)

```bash
docker compose exec -T postgres psql -U biblioteca -d biblioteca \
  -v ON_ERROR_STOP=1 -f /scripts/carga-lectores.sql
```

Resultado esperado: 5 cargadas, 3 rechazadas (los tres errores nuevos: Lp 1, Lp 2 y Lp 3
de la tabla de criterios).

```text
psql:/scripts/carga-lectores.sql:9: NOTICE:  extension "pgcrypto" already exists, skipping
CREATE EXTENSION
SET
BEGIN
TRUNCATE TABLE
COPY 9
DELETE 1
INSERT 0 8
UPDATE 8
UPDATE 1
INSERT 0 5
INSERT 0 5
INSERT 0 3
COMMIT
 cargadas | rechazadas 
----------+------------
        5 |          3
(1 row)

 linea |                    motivo                    |                                       contenido                                       
-------+----------------------------------------------+---------------------------------------------------------------------------------------
     7 | documento o correo repetido en el archivo    | 1000000036,Sara Camila,Villegas Torres,Sara.Villegas@correo-ejemplo.edu.co,3002000036
     8 | documento no numérico o de longitud inválida | 1A00000037,Juan Camilo,Ramirez,juan.ramirez@correo-ejemplo.edu.co,3002000037
     9 | teléfono no numérico o de longitud inválida  | 1000000038,Samuel,Moreno Farinango,samuel.moreno@correo-ejemplo.edu.co,300200
(3 rows)
```

El error de la línea 7 no lo detecta la base de datos, el `UNIQUE` del correo distingue mayúsculas, así que `Sara.Villegas` y `sara.villegas` quedan como cadenas distintas. Tampoco lo detecta una consulta a `cuenta`, porque en ese momento ninguna de las dos filas está insertada, las dos vienen en el mismo archivo; esto se detecta el paso 4 del script, que compara las filas del archivo entre sí y rechaza la segunda.

## 4. Repetición de la carga (no debe duplicar)

Se corre el mismo archivo propio una segunda vez.

```bash
docker compose exec -T postgres psql -U biblioteca -d biblioteca \
  -v ON_ERROR_STOP=1 -f /scripts/carga-lectores.sql
```

Resultado esperado: 0 cargadas, 8 rechazadas, las 5 que ya estaban dan "documento ya
existe" y las 3 malas siguen cayendo por su propio motivo.

```text
psql:/scripts/carga-lectores.sql:9: NOTICE:  extension "pgcrypto" already exists, skipping
CREATE EXTENSION
SET
BEGIN
TRUNCATE TABLE
COPY 9
DELETE 1
INSERT 0 8
UPDATE 8
UPDATE 0
INSERT 0 0
INSERT 0 0
INSERT 0 8
COMMIT
 cargadas | rechazadas 
----------+------------
        0 |          8
(1 row)

 linea |                    motivo                    |                                       contenido                                       
-------+----------------------------------------------+---------------------------------------------------------------------------------------
     2 | documento ya existe                          | 1000000031,Esteban,Quintero Lozano,esteban.quintero@correo-ejemplo.edu.co,3002000031
     3 | documento ya existe                          | 1000000032,Luisa Fernanda,Zapata Ocampo,luisa.zapata@correo-ejemplo.edu.co,3002000032
     4 | documento ya existe                          | 1000000033,Tomás,Arango Betancur,tomas.arango@correo-ejemplo.edu.co,3002000033
     5 | documento ya existe                          | 1000000034,Sara,Villegas Ríos,sara.villegas@correo-ejemplo.edu.co,3002000034
     6 | documento ya existe                          | 1000000035,Alejandra,Mejía Salgado,alejandra.mejia@correo-ejemplo.edu.co,3002000035
     7 | correo ya registrado por otro lector         | 1000000036,Sara Camila,Villegas Torres,Sara.Villegas@correo-ejemplo.edu.co,3002000036
     8 | documento no numérico o de longitud inválida | 1A00000037,Juan Camilo,Ramirez,juan.ramirez@correo-ejemplo.edu.co,3002000037
     9 | teléfono no numérico o de longitud inválida  | 1000000038,Samuel,Moreno Farinango,samuel.moreno@correo-ejemplo.edu.co,300200
(8 rows)
```

## Estado final de la base

```text
 cuentas | cuentas | bitacora 
----------+---------+----------
       25 |      25 |       17
(1 row)
```

25 cuentas = 20 de la semilla + 5 del CSV propio. Las 25 cuentas quedaron con `hash bcrypt` y `tipo_cuenta = 'Lector'`. Las 17 filas de la bitácora son 6 de
la corrida 2, 3 de la corrida 3 y 8 de la corrida 4.

## Prueba de la última línea de defensa

Se comentó a propósito la regla del teléfono en el `CASE` y se volvió a cargar el archivo
con errores. El script original no se modificó, se hizo sobre una copia con esa
línea comentada.

```sql
-- WHEN telefono !~ '^[0-9]{7,10}$'  THEN 'teléfono no numérico o de longitud inválida'
```

```text
psql:/tmp/carga-sin-regla.sql:9: NOTICE:  extension "pgcrypto" already exists, skipping
CREATE EXTENSION
SET
BEGIN
TRUNCATE TABLE
COPY 7
DELETE 1
INSERT 0 6
UPDATE 6
UPDATE 0
psql:/tmp/carga-sin-regla.sql:61: ERROR:  value too long for type character varying(10)
```

**Qué pasó.** La fila 5 del archivo (`1000000023,...,tres-cero-cero`) ya no la atrapa el
`CASE`, así que llega hasta el `INSERT` en `cuenta` y el esquema la rechaza. El error no
viene del `CHECK` del patrón sino de la longitud del tipo ya que la columna es `varchar(10)` y `tres-cero-cero`
tiene 14 caracteres, así que el tipo la rechaza antes de que el `CHECK` llegue a evaluarse.

**Qué pasa con las demás filas de esa carga.** No sucede nada, el `INSERT` es un solo statement, así
que el bloque falla completo. Las otras cinco filas de ese archivo que sí estaban bien rechazadas
por el `CASE` tampoco llegan a la bitácora.

**Qué pasa con la bitácora.** No se escribe ninguna fila. Y como todo el script corre
entr `BEGIN` y `COMMIT`, el fallo deshace la transacción entera, incluido el
`TRUNCATE` inicial. Estado después de la prueba:

```text
 cuentas | cuentas | bitacora 
----------+---------+----------
       25 |      25 |       17
(1 row)
```

`stg_cuenta` conservó las 8 filas de la corrida anterior, que es la prueba de que el
rollback alcanzó también a las tablas de paso.

**Conclusión.** El `CHECK` y el tipo de dato son la última línea de defensa, pero cuando
actúan ya no hay nada que hacer, no hay carga parcial ni registro del rechazo. La validación en el
`CASE` no es trivial, es lo que permite que un archivo con errores se cargue igual, esto permite que las filas buenas entran y las malas quedan documentadas.
