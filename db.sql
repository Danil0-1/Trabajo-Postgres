-- Active: 1755713709409@@127.0.0.1@5432@campus

DROP SCHEMA IF EXISTS miscompras CASCADE;
CREATE SCHEMA IF NOT EXISTS miscompras;
SET search_path TO miscompras;

CREATE TABLE clientes (
    id_cliente      SERIAL PRIMARY KEY,
    nombre          VARCHAR(40) NOT NULL,
    apellidos       VARCHAR(40) NOT NULL,
    email           VARCHAR(60) UNIQUE NOT NULL,
    telefono        VARCHAR(15)
);

CREATE TABLE productos (
    id_producto     SERIAL PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    precio          NUMERIC(10,2) NOT NULL,
    stock           INT NOT NULL DEFAULT 0
);

CREATE TABLE facturas (
    id_factura      SERIAL PRIMARY KEY,
    fecha           DATE NOT NULL DEFAULT CURRENT_DATE,
    id_cliente      INT NOT NULL,
    total           NUMERIC(12,2) NOT NULL,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE
);

CREATE TABLE detalle_factura (
    id_detalle      SERIAL PRIMARY KEY,
    id_factura      INT NOT NULL,
    id_producto     INT NOT NULL,
    cantidad        INT NOT NULL CHECK (cantidad > 0),
    subtotal        NUMERIC(12,2) NOT NULL,
    FOREIGN KEY (id_factura) REFERENCES facturas(id_factura) ON DELETE CASCADE,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
);

INSERT INTO clientes (nombre, apellidos, email, telefono) VALUES
('Ana', 'Martínez', 'ana.martinez@email.com', '3101234567'),
('Carlos', 'Gómez', 'carlos.gomez@email.com', '3157654321'),
('Laura', 'Torres', 'laura.torres@email.com', '3009876543');

INSERT INTO productos (nombre, descripcion, precio, stock) VALUES
('Laptop Lenovo', 'Laptop Lenovo i5 8GB RAM', 2500.00, 10),
('Mouse Inalámbrico', 'Mouse Logitech inalámbrico', 80.00, 50),
('Teclado Mecánico', 'Teclado Redragon RGB', 150.00, 20);

INSERT INTO facturas (id_cliente, total) VALUES
(1, 2630.00),
(2, 230.00);

INSERT INTO detalle_factura (id_factura, id_producto, cantidad, subtotal) VALUES
(1, 1, 1, 2500.00),
(1, 2, 1, 80.00),
(2, 3, 1, 150.00),
(2, 2, 1, 80.00);

SELECT * FROM clientes;

SELECT f.id_factura, f.fecha, c.nombre, c.apellidos, f.total
FROM facturas f
JOIN clientes c ON f.id_cliente = c.id_cliente;

SELECT f.id_factura, c.nombre, p.nombre AS producto, d.cantidad, d.subtotal
FROM detalle_factura d
JOIN facturas f ON d.id_factura = f.id_factura
JOIN clientes c ON f.id_cliente = c.id_cliente
JOIN productos p ON d.id_producto = p.id_producto;

-- 1. Top 10 productos por unidades vendidas
SELECT p.nombre,
       SUM(cp.cantidad) AS unidades_vendidas,
       SUM(cp.total)    AS ingreso_total
FROM miscompras.compras_productos cp
JOIN miscompras.productos p USING(id_producto)
GROUP BY p.nombre
ORDER BY unidades_vendidas DESC
LIMIT 10;

-- 2. Promedio y mediana de total pagado por compra
SELECT ROUND(AVG(total_compra),2) AS promedio,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_compra),2) AS mediana
FROM (
  SELECT SUM(total) AS total_compra
  FROM miscompras.compras_productos
  GROUP BY id_compra
) t;

-- 3. Compras por cliente con ranking global
SELECT c.id,
       c.nombre || ' ' || c.apellidos AS cliente,
       COUNT(DISTINCT co.id_compra) AS compras_realizadas,
       SUM(cp.total) AS gasto_total,
       RANK() OVER (ORDER BY SUM(cp.total) DESC) AS ranking
FROM miscompras.clientes c
JOIN miscompras.compras co USING(id)
JOIN miscompras.compras_productos cp USING(id_compra)
GROUP BY c.id, cliente;

-- 4. Métricas diarias
WITH resumen AS (
  SELECT co.fecha::date AS dia,
         COUNT(DISTINCT co.id_compra) AS num_compras,
         SUM(cp.total) AS total_dia,
         AVG(cp.total) AS ticket_promedio
  FROM miscompras.compras co
  JOIN miscompras.compras_productos cp USING(id_compra)
  GROUP BY co.fecha::date
)
SELECT * FROM resumen ORDER BY dia;

-- 5. Productos activos en stock cuyo nombre empieza por “caf”
SELECT * 
FROM miscompras.productos
WHERE estado=1
  AND cantidad_stock>0
  AND nombre ILIKE 'caf%';

-- 6. Productos con precio formateado
SELECT nombre,
       '$ ' || TO_CHAR(precio_venta, 'FM999G999G999D00') AS precio
FROM miscompras.productos
ORDER BY precio_venta DESC;

-- 7. Resumen de canasta por compra
SELECT id_compra,
       ROUND(SUM(total),2) AS subtotal,
       ROUND(SUM(total)*0.19,2) AS iva,
       ROUND(SUM(total)*1.19,2) AS total_con_iva
FROM miscompras.compras_productos
GROUP BY id_compra;

-- 8. Participación % por categoría
SELECT cat.descripcion,
       SUM(cp.total) AS total_categoria,
       ROUND(100.0*SUM(cp.total) / SUM(SUM(cp.total)) OVER (),2) AS participacion
FROM miscompras.compras_productos cp
JOIN miscompras.productos p USING(id_producto)
JOIN miscompras.categorias cat USING(id_categoria)
GROUP BY cat.descripcion;

-- 9. Nivel de stock
SELECT nombre,
       cantidad_stock,
       CASE 
         WHEN cantidad_stock < 50 THEN 'CRÍTICO'
         WHEN cantidad_stock < 200 THEN 'BAJO'
         ELSE 'OK'
       END AS nivel_stock
FROM miscompras.productos
WHERE estado=1
ORDER BY cantidad_stock ASC;

-- 10. Última compra por cliente
SELECT DISTINCT ON (c.id) 
       c.id, c.nombre, c.apellidos,
       co.id_compra, co.fecha,
       SUM(cp.total) AS total
FROM miscompras.clientes c
JOIN miscompras.compras co USING(id)
JOIN miscompras.compras_productos cp USING(id_compra)
GROUP BY c.id, co.id_compra
ORDER BY c.id, co.fecha DESC;

-- 11. Top 2 productos más vendidos por categoría
SELECT descripcion AS categoria, nombre, unidades_vendidas
FROM (
  SELECT cat.descripcion, p.nombre,
         SUM(cp.cantidad) AS unidades_vendidas,
         ROW_NUMBER() OVER (PARTITION BY cat.descripcion ORDER BY SUM(cp.cantidad) DESC) AS rn
  FROM miscompras.compras_productos cp
  JOIN miscompras.productos p USING(id_producto)
  JOIN miscompras.categorias cat USING(id_categoria)
  GROUP BY cat.descripcion, p.nombre
) t
WHERE rn <= 2;

-- 12. Ventas mensuales
SELECT DATE_TRUNC('month', co.fecha) AS mes,
       COUNT(DISTINCT co.id_compra) AS compras,
       SUM(cp.total) AS ventas
FROM miscompras.compras co
JOIN miscompras.compras_productos cp USING(id_compra)
GROUP BY DATE_TRUNC('month', co.fecha)
ORDER BY mes;

-- 13. Productos nunca vendidos
SELECT p.*
FROM miscompras.productos p
WHERE NOT EXISTS (
  SELECT 1 FROM miscompras.compras_productos cp
  WHERE cp.id_producto=p.id_producto
);

-- 14. Clientes que compraron café y pan en la misma compra
SELECT DISTINCT co.id_cliente, co.id_compra
FROM miscompras.compras co
WHERE EXISTS (
  SELECT 1
  FROM miscompras.compras_productos cp
  JOIN miscompras.productos p USING(id_producto)
  WHERE cp.id_compra=co.id_compra AND p.nombre ILIKE '%café%'
)
AND EXISTS (
  SELECT 1
  FROM miscompras.compras_productos cp
  JOIN miscompras.productos p USING(id_producto)
  WHERE cp.id_compra=co.id_compra AND p.nombre ILIKE '%pan%'
);

-- 15. Margen porcentual simulado
SELECT nombre,
       ROUND(((precio_venta - (precio_venta*0.7)) / precio_venta)*100,1) AS margen_pct
FROM miscompras.productos;

-- 16. Clientes de un dominio
SELECT *
FROM miscompras.clientes
WHERE TRIM(correo_electronico) ~* '@example\.com$';

-- 17. Normalizar nombres
SELECT id,
       INITCAP(TRIM(nombre)) AS nombre,
       INITCAP(TRIM(apellidos)) AS apellidos
FROM miscompras.clientes;

-- 18. Productos con id par
SELECT * FROM miscompras.productos WHERE id_producto % 2 = 0;

-- 19. Vista ventas_por_compra
CREATE OR REPLACE VIEW miscompras.ventas_por_compra AS
SELECT co.id_compra, co.id_cliente, co.fecha, SUM(cp.total) AS total
FROM miscompras.compras co
JOIN miscompras.compras_productos cp USING(id_compra)
GROUP BY co.id_compra, co.id_cliente, co.fecha;

-- 20. Vista materializada mensual
CREATE MATERIALIZED VIEW IF NOT EXISTS miscompras.mv_ventas_mensuales AS
SELECT DATE_TRUNC('month', co.fecha) AS mes,
       SUM(cp.total) AS total
FROM miscompras.compras co
JOIN miscompras.compras_productos cp USING(id_compra)
GROUP BY DATE_TRUNC('month', co.fecha);

-- Refrescar:
-- REFRESH MATERIALIZED VIEW miscompras.mv_ventas_mensuales;

-- 21. UPSERT de producto
INSERT INTO miscompras.productos (nombre,id_categoria,codigo_barras,precio_venta,cantidad_stock,estado)
VALUES ('Nuevo Producto',1,'7709999999999',5000,100,1)
ON CONFLICT (codigo_barras)
DO UPDATE SET nombre=EXCLUDED.nombre,
              precio_venta=EXCLUDED.precio_venta;

-- 22. Recalcular stock
UPDATE miscompras.productos p
SET cantidad_stock = GREATEST(0, p.cantidad_stock - COALESCE(v.vendidos,0))
FROM (
  SELECT id_producto, SUM(cantidad) AS vendidos
  FROM miscompras.compras_productos
  GROUP BY id_producto
) v
WHERE p.id_producto=v.id_producto;

-- 23. Función total de compra
CREATE OR REPLACE FUNCTION miscompras.fn_total_compra(p_id_compra INT)
RETURNS NUMERIC(16,2) AS $$
DECLARE total NUMERIC(16,2);
BEGIN
  SELECT COALESCE(SUM(total),0) INTO total
  FROM miscompras.compras_productos
  WHERE id_compra=p_id_compra;
  RETURN total;
END;
$$ LANGUAGE plpgsql;

-- 24. Trigger para descontar stock
CREATE OR REPLACE FUNCTION miscompras.fn_descuento_stock()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE miscompras.productos
  SET cantidad_stock = GREATEST(0,cantidad_stock - NEW.cantidad)
  WHERE id_producto=NEW.id_producto;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_descuento_stock
AFTER INSERT ON miscompras.compras_productos
FOR EACH ROW
EXECUTE FUNCTION miscompras.fn_descuento_stock();

-- 25. Ranking por precio en su categoría
SELECT cat.descripcion, p.nombre, p.precio_venta,
       DENSE_RANK() OVER (PARTITION BY cat.descripcion ORDER BY p.precio_venta DESC) AS pos_precio
FROM miscompras.productos p
JOIN miscompras.categorias cat USING(id_categoria);

-- 26. Gasto por compra y delta entre compras
WITH gastos AS (
  SELECT c.id_cliente, co.fecha::date AS dia, SUM(cp.total) AS gasto
  FROM miscompras.compras co
  JOIN miscompras.compras_productos cp USING(id_compra)
  GROUP BY c.id_cliente, co.fecha::date
)
SELECT id_cliente, dia, gasto,
       LAG(gasto) OVER (PARTITION BY id_cliente ORDER BY dia) AS gasto_anterior,
       gasto - LAG(gasto) OVER (PARTITION BY id_cliente ORDER BY dia) AS delta
FROM gastos g
JOIN miscompras.compras c ON g.id_cliente=c.id_cliente;
