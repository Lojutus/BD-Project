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
