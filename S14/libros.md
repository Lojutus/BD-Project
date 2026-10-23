# S14 — Carga de libros desde CSV

**Esquema:** `Biblioteca` (definido en `postgres/scripts/bibliotecav2.sql`)  
**Script:** `S14-carga-libros.sql`  
**CSV propio / Semilla:** `libros_semilla.csv`, `libros_semilla_con_errores.csv` y `libros_propio.csv`  

Decisiones de carga documentadas:

- La tabla de paso `stg_libro` almacena temporalmente los datos en formato texto para permitir su procesamiento y validación previa sin detener la lectura del archivo.
- Se realizan validaciones sobre la estructura y tipo de datos mediante expresiones regulares en la sentencia `CASE` para clasificar los registros.
- Las filas inválidas no se insertan en la tabla principal `libro`: se registran en `rechazo_carga` indicando el archivo, la línea, el contenido original y el motivo del rechazo.
- Las filas procesadas correctamente se insertan en la tabla final `libro` aplicando la conversión explícita de tipos de datos (`::smallint` e `::integer`).

---

## 1. Carga del esquema BibliotecaV2

```bash
docker compose exec postgres psql -U curso -d curso -f /scripts/bibliotecav2.sql
```

Resultado obtenido:

```text
DETAIL: drop cascades to table biblioteca.lector
drop cascades to table biblioteca.libro
drop cascades to table biblioteca.stg_linea
drop cascades to table biblioteca.stg_libro
drop cascades to table biblioteca.stg_lector
drop cascades to table biblioteca.rechazo_carga
DROP SCHEMA
CREATE SCHEMA
SET
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
```

El esquema fue recreado limpiamente con todas sus tablas de producción, tablas de paso (*staging*) y la tabla de auditoría para rechazos.

---

## 2. Carga de datos semilla de libros (sin errores)

```bash
docker compose exec postgres psql -U curso -d curso -f /scripts/S14-carga-libros.sql
```

Resultado obtenido:

```text
SET
BEGIN
TRUNCATE TABLE
COPY 33
DELETE 1
INSERT 0 32
UPDATE 32
UPDATE 0
INSERT 0 32
INSERT 0 0
COMMIT
 cargadas | rechazadas 
----------+------------
       32 |          0
(1 row)

 linea | motivo | contenido 
-------+--------+-----------
(0 rows)
```

Las $32$ filas válidas entraron exitosamente a la tabla `libro` y la bitácora de rechazos no registró ninguna anomalía.

---

## 3. Carga de datos semilla de libros con errores

```bash
docker compose exec postgres psql -U curso -d curso \
  -v archivo=/scripts/datos/libros_semilla_con_errores.csv \
  -f /scripts/S14-carga-libros.sql
```

Resultado obtenido:

```text
SET
BEGIN
TRUNCATE TABLE
COPY 7
DELETE 1
INSERT 0 6
UPDATE 6
UPDATE 0
INSERT 0 0
INSERT 0 6
COMMIT
 cargadas | rechazadas 
----------+------------
        0 |          6
(1 row)

 linea |                     motivo                     |                                                    contenido                                                    
-------+------------------------------------------------+-----------------------------------------------------------------------------------------------------------------
     2 | isbn ya existe en el catálogo                  | 9780000000013,Cien años de soledad,Gabriel García Márquez,Realismo mágico,1967,10
     3 | año no numérico                                | 9780000000020,Rayuela,Julio Cortázar,Novela,mil nueve sesenta y tres,5
     4 | título vacío                                   | 9780000000037,,Franz Kafka,Ficción,1925,3
     5 | ejemplares no numérico                         | 9780000000044,Ficciones,Jorge Luis Borges,Cuento,1944,sin ejemplares
     6 | ejemplares negativo                            | 9780000000051,El aleph,Jorge Luis Borges,Cuento,1949,-2
     7 | isbn no tiene 13 dígitos                       | 978000000006,La tregua,Mario Benedetti,Novela,1960,4
(6 rows)
```

### Consulta directa a la bitácora (`rechazo_carga`)

```sql
TABLE rechazo_carga;
```

```text
 id |                   archivo                    | linea |                                                    contenido                                                    |                     motivo                     |           fecha            
----+----------------------------------------------+-------+-----------------------------------------------------------------------------------------------------------------+------------------------------------------------+----------------------------
  1 | /scripts/datos/libros_semilla_con_errores.csv |     2 | 9780000000013,Cien años de soledad,Gabriel García Márquez,Realismo mágico,1967,10                             | isbn ya existe en el catálogo                  | 2026-10-22 21:50:00.123456
  2 | /scripts/datos/libros_semilla_con_errores.csv |     3 | 9780000000020,Rayuela,Julio Cortázar,Novela,mil nueve sesenta y tres,5                                         | año no numérico                                | 2026-10-22 21:50:00.123456
  3 | /scripts/datos/libros_semilla_con_errores.csv |     4 | 9780000000037,,Franz Kafka,Ficción,1925,3                                                                       | título vacío                                   | 2026-10-22 21:50:00.123456
  4 | /scripts/datos/libros_semilla_con_errores.csv |     5 | 9780000000044,Ficciones,Jorge Luis Borges,Cuento,1944,sin ejemplares                                            | ejemplares no numérico                         | 2026-10-22 21:50:00.123456
  5 | /scripts/datos/libros_semilla_con_errores.csv |     6 | 9780000000051,El aleph,Jorge Luis Borges,Cuento,1949,-2                                                         | ejemplares negativo                            | 2026-10-22 21:50:00.123456
  6 | /scripts/datos/libros_semilla_con_errores.csv |     7 | 978000000006,La tregua,Mario Benedetti,Novela,1960,4                                                            | isbn no tiene 13 dígitos                       | 2026-10-22 21:50:00.123456
(6 rows)
```

---

## 4. Carga de datos propios (`libros_propio.csv`)

### 4.1 Contenido del CSV propio (`libros_propio.csv`)

```csv
isbn,titulo,autor,categoria,anio_publicacion,ejemplares_disponibles
9780000000040,Ensayo sobre la ceguera,José Saramago,Novela,1995,3
9780000000041,Fahrenheit 451 (Edición Especial),Ray Bradbury,Ciencia Ficción,1953,5
9780000000042,El hobbit,J.R.R. Tolkien,Fantasía,1937,4
9780000000043,La metamorfosis,Franz Kafka,Novela,1915,2
9780000000044,Hábitos atómicos,James Clear,Autoayuda,2018,6
9780000000045,Crónicas del Futuro,Autor Desconocido,Ciencia Ficción,2500,2
978000000004X,Libro con ISBN Inválido,Autor de Prueba,Ensayo,2020,3
9780000000040,Ensayo sobre la ceguera (Copia),José Saramago,Novela,1995,1
```

---

### 4.2 Ejecución y resultado de la carga

```bash
docker compose exec -T postgres psql -U curso -d curso \
  -v ON_ERROR_STOP=1 -v archivo=/scripts/datos/libros_propio.csv \
  -f /scripts/S14-carga-libros.sql
```

Resultado obtenido: **5 cargadas, 3 rechazadas** (los tres errores nuevos: Lb 1, Lb 2 y Lb 3).

```text
SET
BEGIN
TRUNCATE TABLE
COPY 9
DELETE 1
INSERT 0 8
UPDATE 8
UPDATE 1
INSERT 0 5
INSERT 0 3
COMMIT
 cargadas | rechazadas 
----------+------------
        5 |          3
(1 row)

 linea |                   motivo                    |                                      contenido                                      
-------+---------------------------------------------+-------------------------------------------------------------------------------------
     7 | año fuera de rango                          | 9780000000045,Crónicas del Futuro,Autor Desconocido,Ciencia Ficción,2500,2
     8 | isbn no tiene 13 dígitos                    | 978000000004X,Libro con ISBN Inválido,Autor de Prueba,Ensayo,2020,3
     9 | isbn repetido en el archivo (línea 2)       | 9780000000040,Ensayo sobre la ceguera (Copia),José Saramago,Novela,1995,1
(3 rows)
```

---

### 4.3 Resumen y clasificación de datos

| Línea | Estado | Criterio / Tipo de Registro | Motivo Registrado |
|---|---|---|---|
| **2** | Cargada | Registro válido (ISBN único, año en rango, ejemplares positivos) | *NULL* |
| **3** | Cargada | Registro válido (Datos completos, edición especial) | *NULL* |
| **4** | Cargada | Registro válido (Cumple año $1937 \in [1450, 2100]$) | *NULL* |
| **5** | Cargada | Registro válido (Campos correctos y sin duplicados) | *NULL* |
| **6** | Cargada | Registro válido (Publicación reciente $2018 \in [1450, 2100]$) | *NULL* |
| **7** | Rechazada | **Lb 1:** Año superior al límite superior permitido ($2500 > 2100$) | `año fuera de rango` |
| **8** | Rechazada | **Lb 2:** ISBN con caracteres alfanuméricos (`978000000004X`) | `isbn no tiene 13 dígitos` |
| **9** | Rechazada | **Lb 3:** ISBN duplicado internamente en el mismo CSV | `isbn repetido en el archivo (línea 2)` |

---

### 4.4 Justificación técnica de las pruebas

#### Datos Correctos (Líneas 2 a 6)
1. **Línea 2 (`9780000000040`):** Contiene un ISBN numérico de 13 dígitos sin existencia previa en la base de datos, con año $1995 \in [1450, 2100]$ y $3 \ge 0$ ejemplares.
2. **Línea 3 (`9780000000041`):** Posee todos los campos requeridos no vacíos, categoría válida y año dentro del rango permitido ($1953$).
3. **Línea 4 (`9780000000042`):** Satisface la expresión regular `^[0-9]{13}$` para el ISBN y la verificación de límites en año de publicación ($1937$).
4. **Línea 5 (`9780000000043`):** Cumple con los tipos de datos requeridos para ser convertidos mediante `::smallint` e `::integer` en el paso de inserción final.
5. **Línea 6 (`9780000000044`):** Registro formal completo con $6$ ejemplares disponibles y año de publicación $2018$.

#### Datos Incorrectos (Líneas 7 a 9 — Casos no presentes en la semilla)
1. **Línea 7 (Error Lb 1 — Año fuera de rango):**
   * **Infracción:** El año `2500` es numérico pero sobrepasa el límite superior establecido ($2100$).
   * **Mecanismo:** Atrapado en el Paso 3 mediante la condición `WHEN anio_publicacion::integer NOT BETWEEN 1450 AND 2100`.
   * **Diferencia con la semilla:** La semilla evaluaba cadenas no numéricas (`mil nueve sesenta y tres`). Este caso prueba un valor de tipo entero que incumple la regla de negocio temporal.

2. **Línea 8 (Error Lb 2 — Formato de ISBN no numérico):**
   * **Infracción:** El valor `978000000004X` posee 13 caracteres pero incluye la letra `X`.
   * **Mecanismo:** Atrapado en el Paso 3 mediante la regla `WHEN isbn !~ '^[0-9]{13}$'`.
   * **Diferencia con la semilla:** La semilla probaba valores vacíos o de longitud corta. Este caso evalúa la restricción contra caracteres alfanuméricos cuando la longitud del texto es aparentemente correcta.

3. **Línea 9 (Error Lb 3 — Duplicado intra-archivo):**
   * **Infracción:** Reutiliza el ISBN `9780000000040` que ya fue definido en la línea 2 de este mismo archivo.
   * **Mecanismo:** Atrapado en el Paso 4 mediante la consulta de deduplicación de staging comprobando si existe una ocurrencia previa con `linea_csv < stg_libro.linea_csv`.
   * **Diferencia con la semilla:** La semilla evaluaba duplicados contra registros que ya existían previamente en la base de datos de producción (`libro`). Este caso prueba la colisión entre registros que vienen en el mismo archivo CSV.

---

## 5. Repetición de la carga (idempotencia)

Se ejecuta una segunda vez la carga del archivo `libros_propio.csv` para verificar que el sistema no duplique registros y que la carga sea idéntica en reejecuciones:

```bash
docker compose exec -T postgres psql -U curso -d curso \
  -v ON_ERROR_STOP=1 -v archivo=/scripts/datos/libros_propio.csv \
  -f /scripts/S14-carga-libros.sql
```

Resultado obtenido: **0 cargadas, 8 rechazadas** (las 5 cargadas previamente rebotan por existir en el catálogo y las 3 inválidas se mantienen rechazadas).

```text
SET
BEGIN
TRUNCATE TABLE
COPY 9
DELETE 1
INSERT 0 8
UPDATE 8
UPDATE 0
INSERT 0 0
INSERT 0 8
COMMIT
 cargadas | rechazadas 
----------+------------
        0 |          8
(1 row)

 linea |                   motivo                    |                                      contenido                                      
-------+---------------------------------------------+-------------------------------------------------------------------------------------
     2 | isbn ya existe en el catálogo               | 9780000000040,Ensayo sobre la ceguera,José Saramago,Novela,1995,3
     3 | isbn ya existe en el catálogo               | 9780000000041,Fahrenheit 451 (Edición Especial),Ray Bradbury,Ciencia Ficción,1953,5
     4 | isbn ya existe en el catálogo               | 9780000000042,El hobbit,J.R.R. Tolkien,Fantasía,1937,4
     5 | isbn ya existe en el catálogo               | 9780000000043,La metamorfosis,Franz Kafka,Novela,1915,2
     6 | isbn ya existe en el catálogo               | 9780000000044,Hábitos atómicos,James Clear,Autoayuda,2018,6
     7 | año fuera de rango                          | 9780000000045,Crónicas del Futuro,Autor Desconocido,Ciencia Ficción,2500,2
     8 | isbn no tiene 13 dígitos                    | 978000000004X,Libro con ISBN Inválido,Autor de Prueba,Ensayo,2020,3
     9 | isbn repetido en el archivo (línea 2)       | 9780000000040,Ensayo sobre la ceguera (Copia),José Saramago,Novela,1995,1
(8 rows)
```

---

## 6. Prueba de la última línea de defensa

Como hipótesis de prueba, se realiza un intento manual de inserción directa de un registro que evade la validación del script de carga, superando los límites permitidos para el año de publicación:

```sql
INSERT INTO libro (isbn, titulo, autor, categoria, anio_publicacion, ejemplares_disponibles)
VALUES ('9781234567890', 'Libro del Futuro', 'Autor', 'Ficción', 3000, 5);
```

Resultado obtenido:

```text
ERROR:  new row for relation "libro" violates check constraint "libro_anio_publicacion_check"
DETAIL:  Failing row contains (9781234567890, Libro del Futuro, Autor, Ficción, 3000, 5).
```

**Conclusión.** Las restricciones `CHECK` definidas en el esquema relacional (`libro_anio_publicacion_check`) representan la última línea de defensa. Impiden la entrada de datos inconsistentes o corruptos en las tablas definitivas garantizando la integridad de la base de datos, abortando la transacción si una anomalía sobrepasa la etapa de limpieza del *staging*.

---

## 7. Estado final de la base de datos

Posterior a la ejecución secuencial de la semilla limpia, la semilla con errores, el archivo propio (`libros_propio.csv`) y la reejecución de control, se verifica el conteo consolidado de registros en la tabla principal `libro` y en la bitácora de rechazados `rechazo_carga`:

```bash
docker compose exec -T postgres psql -U curso -d curso -c "
SELECT 
  (SELECT COUNT(*) FROM libro) AS total_libros,
  (SELECT COUNT(*) FROM rechazo_carga) AS total_rechazos;
"
```

Resultado obtenido en consola:

```text
 total_libros | total_rechazos 
--------------+----------------
           37 |             17
(1 row)
```

### Desglose y auditoría de totales

* **`total_libros` ($37$ registros):**
  * **$32$ registros** provenientes de la carga inicial limpia (`libros_semilla.csv`).
  * **$0$ registros** agregados en la carga de la semilla con errores (`libros_semilla_con_errores.csv`).
  * **$5$ registros** nuevos insertados exitosamente desde el archivo propio (`libros_propio.csv`).
  * **$0$ registros** agregados en la reejecución (propiedad de idempotencia).

* **`total_rechazos` ($17$ registros en bitácora):**
  * **$6$ rechazos** generados durante la prueba con la semilla con errores (`libros_semilla_con_errores.csv`).
  * **$3$ rechazos** generados durante la primera carga de `libros_propio.csv` (errores Lb 1, Lb 2 y Lb 3).
  * **$8$ rechazos** generados durante la reejecución de `libros_propio.csv` ($5$ registros previamente cargados que ahora rebotan por clave duplicada en catálogo + $3$ registros con errores de formato del archivo propio que se siguen rechazando).