# `postgres/init/`

Scripts SQL (o `.sh`) que Postgres ejecuta **una sola vez**, en orden
alfabético, **solo si `postgres/data/` está vacía** (es decir, la primera vez
que se crea la base, o después de borrarla para empezar de cero).

Convención de nombres: prefijo numérico de dos dígitos para controlar el
orden.

```
01_esquema.sql   -- CREATE TABLE, constraints, etc.
02_datos.sql     -- INSERT de datos semilla
```
