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
