-- SCRIPT PARA CARGA INCREMENTAL DE DATOS
-- Contiene ejemplos simplificados para la carga incremental al data warehouse

USE DW_TemuColombia
GO

-- =============================================
-- TABLA DE CONTROL DE CARGAS
-- =============================================

-- Crear tabla para el control de cargas incrementales
IF OBJECT_ID('ControlCargaDW', 'U') IS NULL
BEGIN
    CREATE TABLE ControlCargaDW (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        NombreTabla NVARCHAR(100) NOT NULL,
        UltimaFechaCarga DATETIME NOT NULL,
        UltimoIDCargado BIGINT NULL,
        RegistrosInsertados INT DEFAULT 0,
        RegistrosActualizados INT DEFAULT 0,
        FechaEjecucion DATETIME NOT NULL DEFAULT GETDATE()
    );
    
    -- Inicializar tabla con registros para cada tabla del DW
    INSERT INTO ControlCargaDW (NombreTabla, UltimaFechaCarga, FechaEjecucion)
    VALUES 
        ('DimProducto', GETDATE(), GETDATE()),
        ('DimCliente', GETDATE(), GETDATE()),
        ('FactVentas', GETDATE(), GETDATE()),
        ('FactInventario', GETDATE(), GETDATE()),
        ('FactEnvios', GETDATE(), GETDATE());
END
GO

-- =============================================
-- EJEMPLOS DE CARGA INCREMENTAL
-- =============================================

-- 1. Ejemplo de carga incremental para DimProducto (SCD Tipo 2)
-- Este procedimiento actualiza la dimensión producto con nuevos registros o cambios
PRINT 'Ejemplo 1: Carga incremental de DimProducto'

-- Simular nuevos productos en la tabla fuente
USE BDTemuColombia
GO

-- Insertar un nuevo producto en la tabla fuente
INSERT INTO Productos (nombre, descripcion, precio, categoria)
VALUES (
    'Nuevo Smartphone XYZ',
    'Smartphone de última generación con cámara de 108MP',
    2500000.00,
    'Celulares'
)

-- Actualizar un producto existente
UPDATE Productos
SET precio = precio * 1.10 -- Incremento de precio del 10%
WHERE id = 5

USE DW_TemuColombia
GO

-- Ejemplo de carga incremental para DimProducto
DECLARE @UltimaFechaCarga DATETIME
SELECT @UltimaFechaCarga = UltimaFechaCarga FROM ControlCargaDW WHERE NombreTabla = 'DimProducto'

-- Identificar cambios en productos (nuevos o modificados)
SELECT 
    p.id,
    'PROD_' + CAST(p.id AS NVARCHAR(10)),
    p.nombre,
    p.descripcion,
    p.categoria,
    p.precio,
    'NUEVO' as TipoCambio
FROM 
    BDTemuColombia.dbo.Productos p
    LEFT JOIN DimProducto dp ON p.id = dp.ProductoID
WHERE 
    dp.ProductoID IS NULL -- Productos nuevos

UNION

SELECT 
    p.id,
    'PROD_' + CAST(p.id AS NVARCHAR(10)),
    p.nombre,
    p.descripcion,
    p.categoria,
    p.precio,
    'ACTUALIZADO' as TipoCambio
FROM 
    BDTemuColombia.dbo.Productos p
    INNER JOIN DimProducto dp ON p.id = dp.ProductoID
WHERE 
    p.nombre <> dp.NombreProducto OR
    p.descripcion <> dp.Descripcion OR
    p.categoria <> dp.Categoria OR
    p.precio <> dp.PrecioActual

-- Actualizar el control de carga
UPDATE ControlCargaDW
SET UltimaFechaCarga = GETDATE()
WHERE NombreTabla = 'DimProducto'

-- 2. Ejemplo de carga incremental para FactVentas
PRINT 'Ejemplo 2: Carga incremental de FactVentas'

-- Simular nuevas ventas en la tabla fuente
USE BDTemuColombia
GO

-- Insertar una nueva venta
INSERT INTO Ventas (fecha, cliente_id, empleado_id, total)
VALUES (
    GETDATE(),
    50, -- Cliente ID
    10, -- Empleado ID
    1500000.00 -- Total
)

-- Obtener el ID de la venta insertada
DECLARE @NuevaVentaID BIGINT = SCOPE_IDENTITY()

-- Insertar detalles de la nueva venta
INSERT INTO DetalleVentas (venta_id, producto_id, cantidad, precio_unitario)
VALUES 
    (@NuevaVentaID, 25, 2, 500000.00),
    (@NuevaVentaID, 50, 1, 500000.00)

USE DW_TemuColombia
GO

-- Ejemplo de carga incremental para FactVentas
DECLARE @UltimoIDCargado BIGINT
SELECT @UltimoIDCargado = UltimoIDCargado FROM ControlCargaDW WHERE NombreTabla = 'FactVentas'

-- Si no hay ID cargado previo, usar 0
IF @UltimoIDCargado IS NULL
    SET @UltimoIDCargado = 0

-- Obtener las nuevas ventas no cargadas al data warehouse
SELECT 
    t.TiempoID,
    dv.producto_id,
    v.cliente_id,
    v.empleado_id,
    dv.cantidad,
    dv.precio_unitario,
    dv.cantidad * dv.precio_unitario AS Total,
    v.id AS VentaSourceID,
    dv.id AS DetalleVentaSourceID
FROM 
    BDTemuColombia.dbo.Ventas v
    INNER JOIN BDTemuColombia.dbo.DetalleVentas dv ON v.id = dv.venta_id
    INNER JOIN DimTiempo t ON CONVERT(date, v.fecha) = t.Fecha
WHERE 
    dv.id > @UltimoIDCargado

-- Actualizar el control de carga con el último ID procesado
UPDATE ControlCargaDW
SET 
    UltimaFechaCarga = GETDATE(),
    UltimoIDCargado = (SELECT MAX(id) FROM BDTemuColombia.dbo.DetalleVentas)
WHERE 
    NombreTabla = 'FactVentas'

-- 3. Ejemplo de carga incremental para FactInventario
PRINT 'Ejemplo 3: Carga incremental de FactInventario'

-- Simular actualización de inventario
USE BDTemuColombia
GO

-- Insertar nueva entrada de inventario
INSERT INTO Inventario (producto_id, cantidad, fecha_actualizacion)
VALUES 
    (10, 50, GETDATE()),
    (20, 75, GETDATE())

USE DW_TemuColombia
GO

-- Ejemplo de carga incremental para FactInventario
DECLARE @UltimaFechaInventario DATETIME
SELECT @UltimaFechaInventario = UltimaFechaCarga FROM ControlCargaDW WHERE NombreTabla = 'FactInventario'

-- Obtener las actualizaciones de inventario desde la última carga
SELECT 
    t.TiempoID,
    i.producto_id,
    i.cantidad,
    i.id AS InventarioSourceID
FROM 
    BDTemuColombia.dbo.Inventario i
    INNER JOIN DimTiempo t ON CONVERT(date, i.fecha_actualizacion) = t.Fecha
WHERE 
    i.fecha_actualizacion > @UltimaFechaInventario

-- Actualizar el control de carga
UPDATE ControlCargaDW
SET UltimaFechaCarga = GETDATE()
WHERE NombreTabla = 'FactInventario'

PRINT 'Ejemplos de carga incremental completados'
GO
