-- ============================================================================
-- CODIGOS DE PRUEBA INDIVIDUALES

-- ----------------------------------------------------------------------------
-- docker compose exec postgres psql -U biblioteca -d biblioteca -f /init/biblioteca.sql

-- docker compose exec postgres psql -U biblioteca -d biblioteca -f /scripts/datos-prueba.sql

-- O SI SOLO QUIERES UN DATO DE PRUEBA SEGURO EN CADA FUNCION:

-- docker compose exec postgres psql -U biblioteca -d biblioteca -f /scripts/pruebas/datos-funciones.sql


-- docker compose exec postgres psql -U biblioteca -d biblioteca -f /scripts/pruebas/pruebas-individuales.sql
-- ----------------------------------------------------------------------------
SET search_path TO Biblioteca;

-- ============================================================================
-- SECCIÓN 1: FUNCIONES DE APOYO  (Responsable: José)


-- ----------------------------------------------------------------------------
-- Regla de negocio: Determina si una cuenta tiene mora activa. Una cuenta está
-- en mora cuando tiene al menos un préstamo abierto (fecha_devolucion IS NULL)
-- cuya fecha_limite ya pasó estrictamente (fecha_limite < CURRENT_DATE).
-- Si la fecha_limite es HOY, todavía NO está en mora.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION en_mora(p_documento varchar)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = Biblioteca
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM prestamo
        WHERE documento_usuario = p_documento
          AND fecha_devolucion IS NULL
          AND fecha_limite < CURRENT_DATE
    );
$$;

-- ----------------------------------------------------------------------------
-- Regla de negocio: Cuenta cuántos préstamos abiertos (sin devolver) tiene
-- actualmente una cuenta. Sirve como apoyo de consulta y diagnóstico.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION prestamos_abiertos(p_documento varchar)
RETURNS bigint
LANGUAGE sql
STABLE
SET search_path = Biblioteca
AS $$
        SELECT COUNT(*)
        FROM prestamo
        WHERE documento_usuario = p_documento
          AND fecha_devolucion IS NULL;
    -- TODO (José): retornar COUNT(*) de prestamo donde
    -- documento_usuario = p_documento y fecha_devolucion IS NULL.
$$;

-- ----------------------------------------------------------------------------
-- Regla de negocio: Selecciona un ejemplar libre de un libro (ISBN) para poder
-- prestarlo. Retorna el menor numero_ejemplar que no tenga un préstamo abierto
-- en prestamo, o NULL si el libro no existe o todos sus ejemplares están
-- prestados.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ejemplar_disponible(p_isbn varchar)
RETURNS smallint
LANGUAGE sql
STABLE
SET search_path = Biblioteca
AS $$
    SELECT e.numero_ejemplar
    FROM ejemplar e
    WHERE e.isbn_libro = p_isbn
        AND NOT EXISTS (
                SELECT 1
                FROM prestamo p
                WHERE p.isbn_libro = e.isbn_libro
                AND p.numero_ejemplar = e.numero_ejemplar
                AND p.fecha_devolucion IS NULL
            ) LIMIT 1;
            
    -- TODO (José): seleccionar e.numero_ejemplar FROM ejemplar e
    -- donde e.isbn_libro = p_isbn y NOT EXISTS un préstamo abierto
    -- para (e.numero_ejemplar, e.isbn_libro), ordenado por e.numero_ejemplar ASC
    -- con LIMIT 1.
$$;
SELECT en_mora('1000000001') AS "Cuenta en mora (debería ser TRUE)";
SELECT prestamos_abiertos('1000000001') AS "Prestamos abiertos (debería ser 1)";
SELECT ejemplar_disponible('9781111111111') AS "Ejemplar disponible (debería ser el 2)";