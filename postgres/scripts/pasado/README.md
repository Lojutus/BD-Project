# `postgres/scripts/pasado/`

`biblioteca-antes.sql` es el esquema **anterior a la normalización** (con la
columna `libro.ejemplares_disponibles` sin mantener). Sirve solo para probar
la migración. **Nunca se corre en la base `biblioteca`**: empieza con
`DROP SCHEMA Biblioteca CASCADE` y borraría el esquema y los datos actuales.

El esquema vigente es `postgres/init/biblioteca.sql`.

## Probar la migración (antes → después)

Se hace en una base aparte, así la base `biblioteca` no se toca:

```bash
# 1. crear una base de prueba
docker compose exec postgres psql -U biblioteca -d biblioteca -c "CREATE DATABASE prueba_migracion;"

# 2. esquema anterior
docker compose exec postgres psql -U biblioteca -d prueba_migracion -v ON_ERROR_STOP=1 -f /scripts/pasado/biblioteca-antes.sql

#3. añadir datos de prueba
docker compose exec postgres psql -U biblioteca -d prueba_migracion -v ON_ERROR_STOP=1 -f /scripts/pasado/datos-prueba-antes.sql

# 4. normalización (S19): crea la vista y elimina la columna
docker compose exec postgres psql -U biblioteca -d prueba_migracion -v ON_ERROR_STOP=1 -f /scripts/normalizacion.sql

# 5. borrar la base de prueba
docker compose exec postgres psql -U biblioteca -d biblioteca -c "DROP DATABASE prueba_migracion WITH (FORCE);"
```