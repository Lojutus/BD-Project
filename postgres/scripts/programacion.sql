-- ============================================================================
-- PROGRAMACIÓN EN BASE DE DATOS - SISTEMA DE BIBLIOTECA (HITO 4)
-- ============================================================================
--
-- GUÍA DE ESTILO Y CONVENCIONES OBLIGATORIAS PARA TODO EL EQUIPO:
--   1. Esquema: mantener SET search_path TO Biblioteca al inicio del archivo y
--      SET search_path = Biblioteca en el encabezado de cada función/procedimiento.
--   2. Idempotencia: usar siempre CREATE OR REPLACE FUNCTION / PROCEDURE y
--      DROP TRIGGER IF EXISTS <trigger> ON <tabla>; antes de cada CREATE TRIGGER,
--      para poder re-ejecutar este archivo varias veces sin errores.
--   3. Nombres: todo en snake_case.
--      - Parámetros de entrada: prefijo p_ (ej. p_documento, p_isbn, p_id_prestamo).
--      - Variables locales en PL/pgSQL: prefijo v_ (ej. v_ejemplar, v_id_prestamo).
--   4. Lenguaje:
--      - Funciones de solo consulta: LANGUAGE sql STABLE.
--      - Procedimientos y funciones de trigger: LANGUAGE plpgsql.
--   5. Mensajes:
--      - Errores de regla de negocio: RAISE EXCEPTION 'Mensaje claro con el valor %', p_param;
--      - Confirmaciones útiles en procedimientos: RAISE NOTICE 'Mensaje con datos clave';
--   6. Reglas activas en este proyecto:
--      - SÍ: solo cuentas sin mora pueden pedir préstamos nuevos.
--      - SÍ: préstamo y devolución encapsulados en procedimientos.
--      - SÍ: validación en BEFORE INSERT y sincronización de libro.ejemplares_disponibles
--            en AFTER sobre prestamo y ejemplar.
--      - NO: no existe límite de máximo 3 préstamos abiertos.
--   7. Nota de esquema: prestamo.documento_usuario referencia a cuenta(documento).
--      Validar existencia de lectores contra la tabla cuenta.
--   8. Respetar exactamente los nombres y firmas definidos abajo (la batería
--      pruebas-programacion.sql depende de ellos).
-- ============================================================================

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
    -- TODO (José): retornar EXISTS (...) sobre prestamo verificando
    -- documento_usuario = p_documento, fecha_devolucion IS NULL y
    -- fecha_limite < CURRENT_DATE.
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
    -- TODO (José): seleccionar e.numero_ejemplar FROM ejemplar e
    -- donde e.isbn_libro = p_isbn y NOT EXISTS un préstamo abierto
    -- para (e.numero_ejemplar, e.isbn_libro), ordenado por e.numero_ejemplar ASC
    -- con LIMIT 1.
$$;


-- ============================================================================
-- SECCIÓN 2: PROCEDIMIENTOS  (Responsables: José y Miguel)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Responsable: José
-- Regla de negocio: Registra un préstamo nuevo asignando automáticamente un
-- ejemplar disponible del libro solicitado, con plazo de 14 días desde hoy.
-- Validaciones obligatorias (en orden, con RAISE EXCEPTION claro):
--   1. La cuenta p_documento debe existir en la tabla cuenta.
--   2. El libro p_isbn debe existir en la tabla libro.
--   3. La cuenta no debe estar en mora (usar en_mora(p_documento)).
--   4. Debe existir un ejemplar libre (usar ejemplar_disponible(p_isbn)).
-- Si pasa todo, inserta en prestamo (fecha_inicio = CURRENT_DATE,
-- fecha_limite = CURRENT_DATE + 14) recuperando el id_prestamo generado y
-- muestra un RAISE NOTICE con id_prestamo, p_isbn y v_ejemplar.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE registrar_prestamo(
    p_documento varchar,
    p_isbn      varchar
)
LANGUAGE plpgsql
SET search_path = Biblioteca
AS $$
DECLARE
    v_ejemplar    smallint;
    v_id_prestamo integer;
BEGIN
    -- TODO (José): implementar las 4 validaciones, el INSERT ... RETURNING id_prestamo
    -- y el RAISE NOTICE informativo.
END;
$$;

-- ----------------------------------------------------------------------------
-- Responsable: Miguel
-- Regla de negocio: Registra la devolución de un préstamo abierto marcando
-- fecha_devolucion = CURRENT_DATE.
-- Validaciones obligatorias:
--   - El préstamo p_id_prestamo debe existir y seguir abierto
--     (fecha_devolucion IS NULL). Si no existe o ya fue devuelto, lanzar
--     RAISE EXCEPTION claro usando IF NOT FOUND.
-- Si actualiza correctamente, mostrar un RAISE NOTICE confirmando la devolución.
-- Nota: no hace falta actualizar libro.ejemplares_disponibles aquí porque de eso
-- se encarga el trigger AFTER de Carlos.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE registrar_devolucion(
    p_id_prestamo integer
)
LANGUAGE plpgsql
SET search_path = Biblioteca
AS $$
BEGIN
    -- TODO (Miguel): ejecutar UPDATE prestamo SET fecha_devolucion = CURRENT_DATE
    -- WHERE id_prestamo = p_id_prestamo AND fecha_devolucion IS NULL;
    -- validar IF NOT FOUND THEN RAISE EXCEPTION ...; END IF;
    -- y emitir RAISE NOTICE.
END;
$$;


-- ============================================================================
-- SECCIÓN 3: TRIGGERS  (Responsable: Carlos)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Regla de negocio: Protege la tabla prestamo ante cualquier INSERT (venga del
-- procedimiento o de un INSERT directo):
--   1. Completa valores por defecto si vienen NULL:
--        - NEW.fecha_inicio := COALESCE(NEW.fecha_inicio, CURRENT_DATE);
--        - NEW.fecha_limite := COALESCE(NEW.fecha_limite, NEW.fecha_inicio + 14);
--   2. Si el préstamo que se inserta es abierto (NEW.fecha_devolucion IS NULL),
--      verifica en_mora(NEW.documento_usuario) y lanza RAISE EXCEPTION si la
--      cuenta está en mora.
--      (Si NEW.fecha_devolucion IS NOT NULL, se trata de un registro histórico
--      ya cerrado y debe permitirse).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validar_prestamo()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = Biblioteca
AS $$
BEGIN
    -- TODO (Carlos): completar fechas por defecto y bloquear INSERT abierto
    -- cuando en_mora(NEW.documento_usuario) sea TRUE. Retornar NEW.
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prestamo_validar ON prestamo;
CREATE TRIGGER prestamo_validar
BEFORE INSERT ON prestamo
FOR EACH ROW
EXECUTE FUNCTION validar_prestamo();

-- ----------------------------------------------------------------------------
-- Regla de negocio: Mantiene sincronizada la columna desnormalizada
-- libro.ejemplares_disponibles ante cualquier cambio en prestamo o ejemplar
-- (INSERT, DELETE o UPDATE de columnas relevantes), usando la fórmula exacta:
--   total de ejemplares del libro - préstamos abiertos del libro.
-- IMPORTANTE sobre TG_OP:
--   - Solo consultar NEW.isbn_libro cuando TG_OP IN ('INSERT', 'UPDATE').
--   - Solo consultar OLD.isbn_libro cuando TG_OP IN ('DELETE', 'UPDATE').
--   (En UPDATE donde cambie isbn_libro, deben recalcularse AMBOS libros: el
--   anterior OLD.isbn_libro y el nuevo NEW.isbn_libro).
-- Ambos tables (prestamo y ejemplar) tienen la columna isbn_libro, así que
-- esta misma función puede servir para los dos triggers.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION actualizar_disponibles()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = Biblioteca
AS $$
BEGIN
    -- TODO (Carlos): recalcular libro.ejemplares_disponibles para NEW.isbn_libro
    -- (en INSERT/UPDATE) y para OLD.isbn_libro (en DELETE, o en UPDATE si
    -- OLD.isbn_libro IS DISTINCT FROM NEW.isbn_libro). Retornar NULL.
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS prestamo_disponibles ON prestamo;
CREATE TRIGGER prestamo_disponibles
AFTER INSERT OR DELETE OR UPDATE OF isbn_libro, fecha_devolucion ON prestamo
FOR EACH ROW
EXECUTE FUNCTION actualizar_disponibles();

DROP TRIGGER IF EXISTS ejemplar_disponibles ON ejemplar;
CREATE TRIGGER ejemplar_disponibles
AFTER INSERT OR DELETE OR UPDATE OF isbn_libro ON ejemplar
FOR EACH ROW
EXECUTE FUNCTION actualizar_disponibles();