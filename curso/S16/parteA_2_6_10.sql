
SET search_path TO tienda;

--Consulta 2
SELECT c.nombre  AS cliente,
       r.nombre  AS referido_por
FROM   cliente c
LEFT JOIN cliente r ON r.id_cliente = c.referido_por
ORDER BY c.id_cliente;
--Consulta 6
WITH gasto AS (
    SELECT   c.id_cliente, c.nombre,
             sum(d.cantidad * d.precio_unitario) AS total
    FROM     cliente c
    JOIN     pedido  p ON p.id_cliente = c.id_cliente
    JOIN     detalle d ON d.id_pedido  = p.id_pedido
    WHERE    p.estado <> 'cancelado'
    GROUP BY c.id_cliente, c.nombre
)
--Consulta 10
SELECT nombre, total
FROM   gasto
WHERE  total = (SELECT max(total) FROM gasto);


SELECT   extract(month FROM p.fecha)         AS mes,
         sum(d.cantidad * d.precio_unitario) AS total
FROM     pedido p
JOIN     detalle d ON d.id_pedido = p.id_pedido
WHERE    p.estado <> 'cancelado'
  AND    extract(year FROM p.fecha) = 2026
GROUP BY extract(month FROM p.fecha)
HAVING   sum(d.cantidad * d.precio_unitario) > 200000
ORDER BY mes;
