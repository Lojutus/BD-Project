set SEARCH_PATH to tienda;


--Consulta 1
SELECT c.nombre AS nombre_cliente , pr.nombre AS nombre_producto , d.cantidad , (d.cantidad*pr.precio) AS subtotal
From cliente c
JOIN pedido p ON c.id_cliente = p.id_cliente
JOIN detalle d ON p.id_pedido = d.id_pedido
JOIN producto pr ON d.id_producto = pr.id_producto
WHERE p.id_pedido = 1003;

--Consulta 11
SELECT c.nombre AS nombre_cliente
FROM cliente c
WHERE NOT EXISTS
(
	SELECT 1 FROM producto pr
	WHERE pr.categoria = 'Grano'
	AND NOT EXISTS 
	(
		SELECT 1 
		FROM pedido p 
		JOIN detalle d ON p.id_pedido=d.id_pedido
		WHERE c.id_cliente = p.id_cliente 
		AND pr.id_producto = d.id_producto
		AND p.estado <> 'cancelado'
	)	
);

--Consulta 5
SELECT pr.categoria AS categoria_producto , SUM(d.cantidad*d.precio_unitario) AS total_vendido
FROM pedido p
JOIN detalle d ON p.id_pedido = d.id_pedido
JOIN producto pr on d.id_producto = pr.id_producto
WHERE p.estado <> 'cancelado'
GROUP BY pr.categoria
ORDER BY total_vendido DESC;

--Consulta 4:
SELECT c.nombre AS nombre_cliente, count(p.id_pedido) AS num_pedidos
FROM cliente c
LEFT JOIN pedido p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre
ORDER BY num_pedidos DESC;

--Consulta 8:
SELECT c.nombre AS nombre_cliente
FROM cliente c
WHERE c.ciudad = 'Cali'
AND EXISTS (
    SELECT 1
    FROM pedido p
    JOIN detalle d ON d.id_pedido = p.id_pedido
    JOIN producto pr ON pr.id_producto = d.id_producto
    WHERE p.id_cliente = c.id_cliente
    AND pr.categoria = 'Accesorio'
    AND p.estado <> 'cancelado'
);

--Consulta 7:
SELECT pr.nombre AS nombre_producto, pr.categoria, pr.precio
FROM producto pr
WHERE pr.precio > (
    SELECT avg(pr2.precio)
    FROM producto pr2
    WHERE pr2.categoria = pr.categoria
)
ORDER BY pr.categoria, pr.precio;
