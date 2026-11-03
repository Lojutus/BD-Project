SET search_path TO tienda;

-- Consulta 1: Para el pedido 1003: nombre del cliente, nombre de cada producto, cantidad y subtotal.
SELECT 
    c.nombre AS nombre_cliente, 
    pr.nombre AS nombre_producto, 
    d.cantidad, 
    (d.cantidad * d.precio_unitario) AS subtotal
FROM cliente c
JOIN pedido p ON c.id_cliente = p.id_cliente
JOIN detalle d ON p.id_pedido = d.id_pedido
JOIN producto pr ON d.id_producto = pr.id_producto
WHERE p.id_pedido = 1003;


-- Consulta 2: Cada cliente con el nombre del cliente que lo refirió; los que llegaron solos también deben aparecer.
SELECT 
    c.nombre AS cliente,
    r.nombre AS referido_por
FROM cliente c
LEFT JOIN cliente r ON r.id_cliente = c.referido_por
ORDER BY c.id_cliente;


-- Consulta 3: Productos que nunca se han vendido (en ningún pedido, ni siquiera cancelado).



-- Consulta 4: Cada cliente con su número de pedidos (todos, incluidos los cancelados), mostrando 0 para quien no tiene ninguno.
SELECT 
    c.nombre AS nombre_cliente, 
    COUNT(p.id_pedido) AS num_pedidos
FROM cliente c
LEFT JOIN pedido p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre
ORDER BY num_pedidos DESC;


-- Consulta 5: Total vendido por categoría, sin cancelados, de mayor a menor.
SELECT 
    pr.categoria AS categoria_producto, 
    SUM(d.cantidad * d.precio_unitario) AS total_vendido
FROM pedido p
JOIN detalle d ON p.id_pedido = d.id_pedido
JOIN producto pr ON d.id_producto = pr.id_producto
WHERE p.estado <> 'cancelado'
GROUP BY pr.categoria
ORDER BY total_vendido DESC;


-- Consulta 6: Meses de 2026 en que las ventas (sin cancelados) pasaron de $200 000, con su total.
SELECT 
    EXTRACT(month FROM p.fecha) AS mes,
    SUM(d.cantidad * d.precio_unitario) AS total
FROM pedido p
JOIN detalle d ON d.id_pedido = p.id_pedido
WHERE p.estado <> 'cancelado'
  AND EXTRACT(year FROM p.fecha) = 2026
GROUP BY EXTRACT(month FROM p.fecha)
HAVING SUM(d.cantidad * d.precio_unitario) > 200000
ORDER BY mes;


-- Consulta 7: Productos cuyo precio es mayor que el precio promedio de su categoría.
SELECT 
    pr.nombre AS nombre_producto, 
    pr.categoria, 
    pr.precio
FROM producto pr
WHERE pr.precio > (
    SELECT AVG(pr2.precio)
    FROM producto pr2
    WHERE pr2.categoria = pr.categoria
)
ORDER BY pr.categoria, pr.precio;


-- Consulta 8: Clientes de Cali que han comprado al menos un accesorio, sin cancelados. Cada cliente una sola vez.
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


-- Consulta 9: Explicación de la trampa de NOT IN y versión correcta para "clientes que no han referido a nadie".



-- Consulta 10: El o los clientes que más han gastado (sin cancelados), con su total.
WITH gasto AS (
    SELECT 
        c.id_cliente, 
        c.nombre,
        SUM(d.cantidad * d.precio_unitario) AS total
    FROM cliente c
    JOIN pedido p ON p.id_cliente = c.id_cliente
    JOIN detalle d ON d.id_pedido = p.id_pedido
    WHERE p.estado <> 'cancelado'
    GROUP BY c.id_cliente, c.nombre
)
SELECT nombre, total
FROM gasto
WHERE total = (SELECT MAX(total) FROM gasto);


-- Consulta 11: Clientes que han comprado todos los productos de la categoría Grano, sin cancelados.
SELECT c.nombre AS nombre_cliente
FROM cliente c
WHERE NOT EXISTS (
    SELECT 1 
    FROM producto pr
    WHERE pr.categoria = 'Grano'
    AND NOT EXISTS (
        SELECT 1 
        FROM pedido p 
        JOIN detalle d ON p.id_pedido = d.id_pedido
        WHERE c.id_cliente = p.id_cliente 
        AND pr.id_producto = d.id_producto
        AND p.estado <> 'cancelado'
    )   
);