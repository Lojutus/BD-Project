# `postgres/scripts/`

Scripts SQL sueltos que **no se ejecutan automáticamente** — quedan
disponibles dentro del contenedor en `/scripts` para correrlos a mano,
cuantas veces se quiera, sin perder los datos existentes. Útil para
consultas de una práctica, un `ALTER TABLE`, o probar algo sin tocar el
esquema inicial.

```bash
docker compose exec postgres psql -U biblioteca -d biblioteca -f /scripts/mi_consulta.sql
```

O entrar a una sesión interactiva de `psql` y ejecutar el `\i` desde ahí:

```bash
docker compose exec postgres psql -U biblioteca -d biblioteca
biblioteca=# \i /scripts/mi_consulta.sql
```

Si se desea cargar los datos de libros_semilla.csv / lectores_semilla.csv ejecute los comandos: 
```bash
docker compose exec postgres psql -U biblioteca -d biblioteca -f /scripts/carga-libros.sql
docker compose exec postgres psql -U biblioteca -d biblioteca -f /scripts/carga-lectores.sql
```

Si se desea cargar  los datos de un csv en el esquema diferentes de libros_semilla.csv / lectores_semilla.csv ejecute los siguientes comandos :  
```bash
docker compose exec postgres psql -U biblioteca -d biblioteca -v archivo_libros=/scripts/datos/mis_datos.csv -f /scripts/carga-libros.sql    
docker compose exec postgres psql -U biblioteca -d biblioteca -v archivo_lectores=/scripts/datos/mis_datos.csv -f /scripts/carga-lectores.sql    
```