SET search_path TO Biblioteca;

SELECT c.documento, c.nombres, c.apellidos
FROM   cuenta c
WHERE  EXISTS (SELECT 1
               FROM   prestamo p
               WHERE  p.documento_usuario = c.documento   -- préstamo de ese lector
                 AND  p.fecha_devolucion IS NULL          -- no devuelto
                 AND  p.fecha_limite < CURRENT_DATE)      -- ya vencido
ORDER BY c.apellidos;

SELECT (c.documento, c.nombres, c.correo, c.telefono) AS Pendientes
FROM   cuenta c
WHERE  EXISTS (SELECT documento_usuario, fecha_devolucion, fecha_limite
  FROM   prestamo p
  WHERE  p.documento_usuario = c.documento   -- préstamo de ese lector
  AND    p.fecha_devolucion IS NULL          -- no devuelto 
)                                           
ORDER BY c.apellidos;