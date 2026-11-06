SET search_path TO automotriz;

-- pruebas
--cedula_dueno determina nombre_dueno, telefono_dueno
SELECT cedula_dueno 
FROM servicio_plano
GROUP BY cedula_dueno -- Agrupa 
HAVING count(DISTINCT nombre_dueno) > 1
    OR count(DISTINCT telefono_dueno) > 1; 
--- cod_mecanico determina nombre_mecanico
SELECT cod_mecanico 
FROM servicio_plano
GROUP BY cod_mecanico -- Agrupa
HAVING count(DISTINCT nombre_mecanico) > 1; -- Solo debe de tener un nombre por código de mecánico
--- cod_servicio determina nombre_servicio
SELECT cod_servicio 
FROM servicio_plano
GROUP BY cod_servicio -- Agrupa
HAVING count(DISTINCT nombre_servicio) > 1
        OR count(DISTINCT precio_lista) > 1;-- Solo debe de tener un nombre por código de servicio 
--- placa determina modelo y cedula_dueno
SELECT placa 
FROM servicio_plano
GROUP BY placa -- Agrupa
HAVING count(DISTINCT modelo) > 1
    OR count(DISTINCT cedula_dueno) > 1; -- Solo debe de tener un modelo y cedula_dueno
--- modelo determina marca
SELECT modelo
FROM servicio_plano
GROUP BY modelo -- Agrupa
HAVING count(DISTINCT marca) > 1; -- Solo debe de tener un nombre por código de modelo
--- num_orden determina fecha_ingreso, kilometraje y placa
SELECT num_orden
FROM servicio_plano
GROUP BY num_orden -- Agrupa
HAVING count(DISTINCT fecha_ingreso) > 1
    OR count(DISTINCT kilometraje) > 1
    OR count(DISTINCT placa) > 1;

-- correciones

--muestra del error 
SELECT num_orden, fecha_ingreso, telefono_dueno
FROM servicio_plano
WHERE cedula_dueno = '16700002'
ORDER BY fecha_ingreso; -- El error encontrado , es que el teléfono del dueño con cédula '16700002' cambia de '3104445566' a '3104445567' entre las órdenes (5002 ,5003) y 5006.

-- quizas no esta bien que cambiemos el telefono
-- imaginando que es un cambio de telefono, y que no lo puso mal . tomaremos el ultimo telefono que se tiene registrado.
--  el telefono anterior era de pedidos con varios dias de diferencia, y el telefono nuevo es de un pedido mas reciente. por lo que se puede asumir que el telefono nuevo es el correcto.
UPDATE servicio_plano
SET telefono_dueno = (SELECT telefono_dueno
                      FROM servicio_plano
                      WHERE cedula_dueno = '16700002'
                      ORDER BY fecha_ingreso DESC
                      LIMIT 1)
WHERE cedula_dueno = '16700002'; -- aqui se puede ver que el telefono del dueño con cédula '16700002' cambia de '3104445566' a '3104445567' entre las órdenes (5002 ,5003) y 5006.

--pre-limpieza
DROP TABLE IF EXISTS dueno CASCADE;
DROP TABLE IF EXISTS mecanico CASCADE;
DROP TABLE IF EXISTS servicio CASCADE;
DROP TABLE IF EXISTS referencia_carro CASCADE;
DROP TABLE IF EXISTS carro CASCADE;
DROP TABLE IF EXISTS orden CASCADE;
DROP TABLE IF EXISTS orden_servicio CASCADE;
--Creación de las tablas el orden importa porque hay llaves foráneas

CREATE TABLE dueno (
    cedula_dueno   varchar(15) PRIMARY KEY,
    nombre_dueno   varchar(80) NOT NULL,
    telefono_dueno varchar(15) NOT NULL
);

CREATE TABLE mecanico (
    cod_mecanico   char(3) PRIMARY KEY,
    nombre_mecanico varchar(80) NOT NULL
);
CREATE TABLE referencia_carro(
    modelo         varchar(30) PRIMARY KEY,
    marca          varchar(30) NOT NULL
);
CREATE TABLE servicio(
    cod_servicio   char(3) PRIMARY KEY,
    nombre_servicio varchar(60) NOT NULL,
    precio_lista     integer NOT NULL
);
CREATE TABLE carro (
    placa          char(6) PRIMARY KEY,
    modelo         varchar(30) NOT NULL REFERENCES referencia_carro(modelo),
    cedula_dueno   varchar(15) NOT NULL REFERENCES dueno(cedula_dueno)
);
CREATE TABLE orden (
    num_orden      integer PRIMARY KEY,
    fecha_ingreso  date NOT NULL,
    kilometraje    integer NOT NULL,
    placa          char(6) NOT NULL REFERENCES carro(placa)
);

CREATE TABLE orden_servicio (
    num_orden      integer NOT NULL REFERENCES orden(num_orden),
    cod_servicio   char(3) NOT NULL REFERENCES servicio(cod_servicio),
    precio_cobrado integer NOT NULL,
    cod_mecanico   char(3) NOT NULL REFERENCES mecanico(cod_mecanico),
    PRIMARY KEY (num_orden, cod_servicio)
);

--llenado de las tablas

INSERT INTO dueno (cedula_dueno, nombre_dueno, telefono_dueno)
SELECT DISTINCT cedula_dueno, nombre_dueno, telefono_dueno
FROM servicio_plano;

INSERT INTO mecanico (cod_mecanico, nombre_mecanico)
SELECT DISTINCT cod_mecanico, nombre_mecanico
FROM servicio_plano;

INSERT INTO referencia_carro (modelo, marca)
SELECT DISTINCT modelo, marca
FROM servicio_plano;

INSERT INTO servicio (cod_servicio, nombre_servicio, precio_lista)
SELECT DISTINCT cod_servicio, nombre_servicio, precio_lista
FROM servicio_plano;

INSERT INTO carro (placa, modelo, cedula_dueno)
SELECT DISTINCT placa, modelo, cedula_dueno
FROM servicio_plano;

INSERT INTO orden (num_orden, fecha_ingreso, kilometraje, placa)
SELECT DISTINCT num_orden, fecha_ingreso, kilometraje, placa
FROM servicio_plano;

INSERT INTO orden_servicio (num_orden, cod_servicio, precio_cobrado, cod_mecanico)
SELECT DISTINCT num_orden, cod_servicio, precio_cobrado, cod_mecanico
FROM servicio_plano;

SELECT count(*) FROM dueno;
SELECT count(*) FROM mecanico;
SELECT count(*) FROM referencia_carro;
SELECT count(*) FROM servicio;
SELECT count(*) FROM carro;
SELECT count(*) FROM orden;
SELECT count(*) FROM orden_servicio; --verificación de que se llenaron las tablas correctamente

-- Reconstruccion de la tabla servicio_plano para verificar que todo este bien
DROP VIEW IF EXISTS reconstruida CASCADE;
CREATE VIEW reconstruida AS
SELECT 
    o.num_orden, o.fecha_ingreso, o.kilometraje, 
    c.placa, c.modelo, 
    rc.marca, 
    d.cedula_dueno, d.nombre_dueno, d.telefono_dueno,
    s.cod_servicio, s.nombre_servicio, s.precio_lista, 
    os.precio_cobrado,
    m.cod_mecanico, m.nombre_mecanico
FROM orden o
JOIN carro c ON o.placa = c.placa
JOIN referencia_carro rc ON c.modelo = rc.modelo
JOIN dueno d ON c.cedula_dueno = d.cedula_dueno
JOIN orden_servicio os ON o.num_orden = os.num_orden
JOIN servicio s ON os.cod_servicio = s.cod_servicio
JOIN mecanico m ON os.cod_mecanico = m.cod_mecanico;
--verificacion
SELECT * FROM servicio_plano EXCEPT SELECT * FROM reconstruida;
SELECT * FROM reconstruida EXCEPT SELECT * FROM servicio_plano;



-- Modficaiones de comprovacion 

--- Modifica el telefono del dueño con cédula '16700002' a '3104400000'
UPDATE dueno SET telefono_dueno = '3104400000' WHERE cedula_dueno = '16700002';
-- después del UPDATE del teléfono: un solo lugar, y la vista lo refleja en todas las filas
SELECT * FROM dueno WHERE cedula_dueno = '16700002';
SELECT DISTINCT num_orden, telefono_dueno FROM reconstruida WHERE cedula_dueno = '16700002';

--- Nuevo mecanico
INSERT INTO mecanico (cod_mecanico, nombre_mecanico) VALUES ('111', 'Lojutus mecanico');
-- después del INSERT del mecánico
SELECT * FROM mecanico WHERE cod_mecanico = '111';

  
--borar una orden 

DELETE FROM orden_servicio WHERE num_orden = 5005;
DELETE FROM orden WHERE num_orden = 5005;
-- después de los DELETE: la orden se fue, pero el carro y los servicios siguen
SELECT * FROM orden WHERE num_orden = 5005;          
SELECT * FROM carro WHERE placa = 'JKL012';          
SELECT * FROM servicio WHERE cod_servicio IN ('ACE','FRE','ALI'); 
