# Taller Diseño de base de datos - Postgres

<img src="https://i.ibb.co/c0rfcc8/image.png" alt="image" border="0">

Teniendo en cuenta el diagrama entidad relación resuelva los siguientes requerimientos:

1. Genere los comandos DDL que permitan la creación de la base de datos del DER suministrado.
2. Genere los comandos DML que permitan insertar datos en la base de datos creada en el paso 1.

## Consultas

1. Obtén el “Top 10” de productos por unidades vendidas y su ingreso total, usando `JOIN ... USING`, agregación con `SUM()`, agrupación con `GROUP BY`, ordenamiento descendente con `ORDER BY` y paginado con `LIMIT`.

2. Calcula el total pagado promedio por compra y la mediana aproximada usando una subconsulta agregada y la función de ventana ordenada `PERCENTILE_CONT(...) WITHIN GROUP`, además de `AVG()` y `ROUND()` para formateo.

3. Lista compras por cliente con gasto total y un ranking global de gasto empleando funciones de ventana (`RANK() OVER (ORDER BY SUM(...) DESC)`), concatenación de texto y `COUNT(DISTINCT ...)`.

4. Calcula por día el número de compras, ticket promedio y total, usando un `CTE (WITH) o (Common Table Expression)“subconsulta con nombre”`, conversión de `fecha ::date`, y agregaciones (`COUNT, AVG, SUM`) con `ORDER BY`.

5. Realiza una búsqueda estilo e-commerce de productos activos y con stock cuyo nombre empiece por “caf”, usando filtros en `WHERE`, comparación numérica y búsqueda case-insensitive con `ILIKE 'caf%'`.

6. Devuelve los productos con el precio formateado como texto monetario usando concatenación `('||')` y `TO_CHAR(numeric, 'FM999G999G999D00')`, ordenando de mayor a menor precio.

   El modelo `'FM999G999G999D00'` se descompone así:

   - `FM`: “Fill Mode”. Quita espacios de relleno a la izquierda/derecha.
   - `9`: dígito opcional. Se muestran tantos como existan; si faltan, no se rellenan con ceros.
   - `0`: dígito obligatorio. Aquí `00` fuerza siempre dos decimales.
   - `G`: separador de miles según la configuración regional (p. ej., `,` en `en_US`, `.` en `es_CO`).
   - `D`: separador decimal según la configuración regional (p. ej., `.` en `en_US`, `,` en `es_CO`).

   Ejemplos

   - Con `lc_numeric = 'en_US'`: `to_char(1234567.5, 'FM999G999G999D00')` → `1,234,567.50`
   - Con `lc_numeric = 'es_CO'`: `to_char(1234567.5, 'FM999G999G999D00')` → `1.234.567,50`

7. Arma el “resumen de canasta” por compra: subtotal, `IVA al 19%` y total con IVA, mediante `SUM()` y `ROUND()` sobre el total por ítem, agrupado por compra.

8. Calcula la participación (%) de cada categoría en las ventas usando agregaciones por categoría y una ventana sobre el total (`SUM(SUM(total)) OVER ()`), más `ROUND()` para el porcentaje.

9. Clasifica el nivel de stock de productos activos (`CRÍTICO/BAJO/OK`) usando `CASE` sobre el campo `cantidad_stock` y ordena por el stock ascendente.

10. Obtén la última compra por cliente utilizando`DISTINCT ON (id_cliente)` combinado con `ORDER BY ... fecha DESC` y una agregación del total de la compra.

11. Devuelve los 2 productos más vendidos por categoría usando una subconsulta con `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY SUM(...) DESC)` y luego filtrando `ROW_NUMBER` <= 2.

12. Calcula ventas mensuales: agrupa por mes truncando la fecha con `DATE_TRUNC('month', fecha)`, cuenta compras distintas (`COUNT(DISTINCT ...)`) y suma ventas, ordenando cronológicamente.

13. Lista productos que nunca se han vendido mediante un anti-join con `NOT EXISTS`, comparando por id_producto.

    `WHERE  NOT EXISTS (
      SELECT *
      FROM   ..
      WHERE  ..
    );`

14. Identifica clientes que, al comprar “café”, también compran “pan” en la misma compra, usando un filtro con `ILIKE` y una subconsulta correlacionada con `EXISTS`.

    `WHERE ...  EXISTS (
      SELECT *
      FROM   ..
      WHERE  ..
    );`

15. Estima el margen porcentual “simulado” de un producto aplicando operadores aritméticos sobre precio_venta y formateo con `ROUND()` a un decimal.

16. Filtra clientes de un dominio dado usando expresiones regulares con el operador `~*` (case-insensitive) y limpieza con `TRIM()` sobre el correo electrónico.

17. Normaliza nombres y apellidos de clientes con `TRIM()` e `INITCAP()` para capitalizar, retornando columnas formateadas.

18. Selecciona los productos cuyo `id_producto` es par usando el operador módulo `%` en la cláusula `WHERE`.

19. Crea una vista ventas_por_compra que consolide `id_compra`,` id_cliente`, `fecha` y el `SUM(total)` por compra, usando `CREATE OR REPLACE VIEW` y `JOIN ... USING`.

20. Crea una vista materializada mensual mv_ventas_mensuales que agregue ventas por `DATE_TRUNC('month', fecha);` recuerda refrescarla con `REFRESH MATERIALIZED VIEW` cuando corresponda.

21. Realiza un “UPSERT” de un producto referenciado por codigo_barras usando `INSERT ... ON CONFLICT (...) DO UPDATE`, actualizando nombre y precio_venta cuando exista conflicto.

22. Recalcula el stock descontando lo vendido a partir de un `UPDATE ... FROM (SELECT ... GROUP BY ...)`, empleando `COALESCE()` y `GREATEST()` para evitar negativos.

23. Implementa una función PL/pgSQL (`miscompras.fn_total_compra`) que reciba `p_id_compra` y retorne el `total` con `COALESCE(SUM(...), 0);` define el tipo de retorno `NUMERIC(16,2)`.

24. Define un trigger `AFTER INSERT` sobre `compras_productos` que descuente stock mediante una función `RETURNS TRIGGER` y el uso del registro `NEW`, protegiendo con `GREATEST()` para no quedar bajo cero.

25. Asigna la “posición por precio” de cada producto dentro de su categoría con `DENSE_RANK() OVER (PARTITION BY ... ORDER BY precio_venta DESC)` y presenta el ranking.

26. Para cada cliente, muestra su gasto por compra, el gasto anterior y el delta entre compras usando `LAG(...) OVER (PARTITION BY id_cliente ORDER BY dia)` dentro de un `CTE` que agrega por día.

## Solución Diseño

```sql
-- Opcional: crea y usa el esquema
DROP SCHEMA IF EXISTS miscompras CASCADE;
CREATE SCHEMA IF NOT EXISTS miscompras;
SET search_path TO miscompras;

CREATE TABLE miscompras.clientes (
    id                 VARCHAR(20)  PRIMARY KEY,
    nombre             VARCHAR(40)  NOT NULL,
    apellidos          VARCHAR(100) NOT NULL,
    celular            NUMERIC(10,0),
    direccion          VARCHAR(80),
    correo_electronico VARCHAR(70)
);

CREATE TABLE miscompras.categorias (
    id_categoria  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descripcion   VARCHAR(45) NOT NULL,
    estado        SMALLINT     NOT NULL DEFAULT 1,
    CONSTRAINT categorias_estado_chk CHECK (estado IN (0,1))
);

CREATE TABLE miscompras.productos (
    id_producto    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(45)   NOT NULL,
    id_categoria   INT           NOT NULL,
    codigo_barras  VARCHAR(150),
    precio_venta   NUMERIC(16,2) NOT NULL,
    cantidad_stock INT           NOT NULL DEFAULT 0,
    estado         SMALLINT      NOT NULL DEFAULT 1,
    CONSTRAINT productos_precio_chk   CHECK (precio_venta >= 0),
    CONSTRAINT productos_stock_chk    CHECK (cantidad_stock >= 0),
    CONSTRAINT productos_estado_chk   CHECK (estado IN (0,1)),
    CONSTRAINT productos_fk_categoria FOREIGN KEY (id_categoria)
        REFERENCES miscompras.categorias(id_categoria)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Unico por código de barras si se usa, permite varios NULL
CREATE UNIQUE INDEX IF NOT EXISTS ux_productos_codigo_barras
    ON miscompras.productos (codigo_barras)
    WHERE codigo_barras IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_productos_id_categoria
    ON miscompras.productos (id_categoria);


CREATE TABLE miscompras.compras (
    id_compra    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente   VARCHAR(20)  NOT NULL,
    fecha        TIMESTAMP    NOT NULL DEFAULT NOW(),
    medio_pago   CHAR(1)      NOT NULL,
    comentario   VARCHAR(300),
    estado       CHAR(1)      NOT NULL,
    CONSTRAINT compras_fk_cliente FOREIGN KEY (id_cliente)
        REFERENCES miscompras.clientes(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Indice para busquedas por cliente
CREATE INDEX IF NOT EXISTS idx_compras_id_cliente
    ON miscompras.compras (id_cliente);

CREATE TABLE miscompras.compras_productos (
    id_compra    INT           NOT NULL,
    id_producto  INT           NOT NULL,
    cantidad     INT           NOT NULL,
    total        NUMERIC(16,2) NOT NULL,
    estado       SMALLINT      NOT NULL DEFAULT 1,
    CONSTRAINT compras_productos_pk PRIMARY KEY (id_compra, id_producto),
    CONSTRAINT compras_productos_cantidad_chk CHECK (cantidad > 0),
    CONSTRAINT compras_productos_total_chk    CHECK (total >= 0),
    CONSTRAINT compras_productos_estado_chk   CHECK (estado IN (0,1)),
    CONSTRAINT compras_productos_fk_compra FOREIGN KEY (id_compra)
        REFERENCES miscompras.compras(id_compra)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT compras_productos_fk_producto FOREIGN KEY (id_producto)
        REFERENCES miscompras.productos(id_producto)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Indice adicional para acelerar consultas por producto
CREATE INDEX IF NOT EXISTS idx_cp_id_producto
    ON miscompras.compras_productos (id_producto);

```

### Datos basados en el Diseño

```sql
SET search_path TO miscompras;

INSERT INTO miscompras.clientes (id, nombre, apellidos, celular, direccion, correo_electronico) VALUES
('CC1001', 'Camila',   'Ramírez Gómez',     3004567890, 'Cra 12 #34-56, Bogotá',      'camila.ramirez@example.com'),
('CC1002', 'Andrés',   'Pardo Salinas',     3109876543, 'Cl 45 #67-12, Medellín',     'andres.pardo@example.com'),
('CC1003', 'Valeria',  'Gutiérrez Peña',    3012223344, 'Av 7 #120-15, Bogotá',       'valeria.gutierrez@example.com'),
('CC1004', 'Juan',     'Soto Cárdenas',     3155556677, 'Cl 9 #8-20, Cali',           'juan.soto@example.com'),
('CC1005', 'Luisa',    'Fernández Ortiz',   3028889911, 'Cra 50 #10-30, Bucaramanga', 'luisa.fernandez@example.com'),
('CC1006', 'Carlos',   'Muñoz Prieto',      3014567890, 'Cl 80 #20-10, Barranquilla', 'carlos.munoz@example.com'),
('CC1007', 'Diana',    'Rojas Castillo',    3126665544, 'Cra 15 #98-45, Bogotá',      'diana.rojas@example.com'),
('CC1008', 'Miguel',   'Vargas Rincón',     3201234567, 'Cl 33 #44-21, Cartagena',    'miguel.vargas@example.com');


INSERT INTO miscompras.categorias (descripcion, estado) VALUES
('Café',       1),
('Lácteos',    1),
('Panadería',  1),
('Aseo',       1),
('Snacks',     1),
('Bebidas',    1);

INSERT INTO miscompras.productos (nombre, id_categoria, codigo_barras, precio_venta, cantidad_stock, estado) VALUES
('Café de Colombia 500g',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Café'),
 '7701234567001', 28000.00,  250, 1),
('Café Orgánico Sierra Nevada 250g',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Café'),
 '7701234567002', 22000.00,  180, 1),
('Leche entera 1L',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Lácteos'),
 '7701234567003',  4200.00,  600, 1),
('Yogur natural 1L',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Lácteos'),
 '7701234567004',  6000.00,  400, 1),
('Pan campesino',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Panadería'),
 '7701234567005',  3500.00,  320, 1),
('Croissant mantequilla',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Panadería'),
 '7701234567006',  2500.00,  500, 1),
('Detergente líquido 1L',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Aseo'),
 '7701234567007', 12000.00,  260, 1),
('Jabón en barra 3un',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Aseo'),
 '7701234567008',  8000.00,  300, 1),
('Papas fritas 150g',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Snacks'),
 '7701234567009',  5500.00,  700, 1),
('Maní salado 200g',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Snacks'),
 '7701234567010',  7000.00,  420, 1),
('Gaseosa cola 1.5L',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Bebidas'),
 '7701234567011',  6500.00,  800, 1),
('Agua sin gas 600ml',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Bebidas'),
 '7701234567012',  2200.00, 1200, 1),
('Té verde botella 500ml',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Bebidas'),
 '7701234567013',  3800.00,  650, 1),
('Chocolate de mesa 250g',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Panadería'),
 '7701234567014',  9000.00,  240, 1),
('Mermelada fresa 300g',
 (SELECT id_categoria FROM miscompras.categorias WHERE descripcion='Panadería'),
 '7701234567015',  7500.00,  260, 1);

INSERT INTO miscompras.compras (id_cliente, fecha, medio_pago, comentario, estado) VALUES
('CC1001', '2025-07-02 10:15:23', 'T', 'Compra semanal',            'A'),
('CC1002', '2025-07-03 18:45:10', 'E', 'Para oficina',              'A'),
('CC1003', '2025-07-05 09:05:00', 'C', NULL,                        'A'),
('CC1001', '2025-07-10 14:22:40', 'T', 'Reabastecimiento café',     'A'),
('CC1004', '2025-07-12 11:11:11', 'E', 'Desayuno fin de semana',    'A'),
('CC1005', '2025-07-15 19:35:05', 'T', 'Compras del mes',           'A'),
('CC1006', '2025-07-18 08:55:30', 'C', 'Limpieza y bebidas',        'A'),
('CC1007', '2025-07-20 16:01:00', 'T', 'Merienda en familia',       'A'),
('CC1008', '2025-07-25 12:20:45', 'E', 'Reunión con amigos',        'A'),
('CC1002', '2025-08-01 17:05:12', 'T', 'Compras para semana',       'A'),
('CC1003', '2025-08-02 10:40:33', 'T', 'Bebidas y snacks',          'A'),
('CC1004', '2025-08-05 13:50:00', 'C', 'Dulces y panadería',        'A');

-- CC1001
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1001' AND fecha='2025-07-02 10:15:23'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Café de Colombia 500g'), 2, 56000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1001' AND fecha='2025-07-02 10:15:23'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Leche entera 1L'), 3, 12600.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1001' AND fecha='2025-07-02 10:15:23'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Pan campesino'), 2, 7000.00, 1);

-- CC1002
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1002' AND fecha='2025-07-03 18:45:10'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Gaseosa cola 1.5L'), 4, 26000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1002' AND fecha='2025-07-03 18:45:10'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Papas fritas 150g'), 5, 27500.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1002' AND fecha='2025-07-03 18:45:10'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Maní salado 200g'), 2, 14000.00, 1);

-- CC1003
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1003' AND fecha='2025-07-05 09:05:00'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Detergente líquido 1L'), 1, 12000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1003' AND fecha='2025-07-05 09:05:00'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Jabón en barra 3un'), 1,  8000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1003' AND fecha='2025-07-05 09:05:00'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Agua sin gas 600ml'), 6, 13200.00, 1);

-- CC1001
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1001' AND fecha='2025-07-10 14:22:40'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Café Orgánico Sierra Nevada 250g'), 1, 22000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1001' AND fecha='2025-07-10 14:22:40'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Mermelada fresa 300g'), 1,  7500.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1001' AND fecha='2025-07-10 14:22:40'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Pan campesino'), 1,  3500.00, 1);

-- CC1004
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1004' AND fecha='2025-07-12 11:11:11'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Yogur natural 1L'), 2, 12000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1004' AND fecha='2025-07-12 11:11:11'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Té verde botella 500ml'), 3, 11400.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1004' AND fecha='2025-07-12 11:11:11'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Chocolate de mesa 250g'), 1,  9000.00, 1);

-- CC1005
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1005' AND fecha='2025-07-15 19:35:05'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Café de Colombia 500g'), 1, 28000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1005' AND fecha='2025-07-15 19:35:05'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Leche entera 1L'), 4, 16800.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1005' AND fecha='2025-07-15 19:35:05'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Gaseosa cola 1.5L'), 2, 13000.00, 1);

-- CC1006
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1006' AND fecha='2025-07-18 08:55:30'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Detergente líquido 1L'), 2, 24000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1006' AND fecha='2025-07-18 08:55:30'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Jabón en barra 3un'), 2, 16000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1006' AND fecha='2025-07-18 08:55:30'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Agua sin gas 600ml'), 12, 26400.00, 1);

-- CC1007
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1007' AND fecha='2025-07-20 16:01:00'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Croissant mantequilla'), 6, 15000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1007' AND fecha='2025-07-20 16:01:00'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Café Orgánico Sierra Nevada 250g'), 2, 44000.00, 1);

-- CC1008
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1008' AND fecha='2025-07-25 12:20:45'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Papas fritas 150g'), 10, 55000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1008' AND fecha='2025-07-25 12:20:45'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Gaseosa cola 1.5L'), 5, 32500.00, 1);

-- CC1002
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1002' AND fecha='2025-08-01 17:05:12'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Leche entera 1L'), 8, 33600.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1002' AND fecha='2025-08-01 17:05:12'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Yogur natural 1L'), 4, 24000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1002' AND fecha='2025-08-01 17:05:12'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Pan campesino'), 4, 14000.00, 1);

-- CC1003
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1003' AND fecha='2025-08-02 10:40:33'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Té verde botella 500ml'), 5, 19000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1003' AND fecha='2025-08-02 10:40:33'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Agua sin gas 600ml'), 10, 22000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1003' AND fecha='2025-08-02 10:40:33'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Maní salado 200g'), 3, 21000.00, 1);

-- CC1004
INSERT INTO miscompras.compras_productos (id_compra, id_producto, cantidad, total, estado) VALUES
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1004' AND fecha='2025-08-05 13:50:00'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Chocolate de mesa 250g'), 2, 18000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1004' AND fecha='2025-08-05 13:50:00'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Mermelada fresa 300g'), 2, 15000.00, 1),
((SELECT id_compra FROM miscompras.compras WHERE id_cliente='CC1004' AND fecha='2025-08-05 13:50:00'),
 (SELECT id_producto FROM miscompras.productos WHERE nombre='Café de Colombia 500g'), 1, 28000.00, 1);

```
