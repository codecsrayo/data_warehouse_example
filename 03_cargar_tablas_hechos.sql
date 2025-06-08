-- SCRIPT PARA CARGAR TABLAS DE HECHOS
-- Este script realiza la carga inicial de datos en las tablas de hechos

USE DW_TemuColombia
GO

-- =============================================
-- CARGA DE TABLAS DE HECHOS
-- =============================================

PRINT 'Iniciando carga de tablas de hechos...'

-- Carga de FactVentas
PRINT 'Cargando tabla de hechos de Ventas...'

INSERT INTO FactVentas (
    TiempoID,
    ProductoID,
    ClienteID,
    EmpleadoID,
    Cantidad,
    PrecioUnitario,
    Total,
    VentaSourceID,
    DetalleVentaSourceID
)
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
    BDTemuColombia.dbo.DetalleVentas dv
    INNER JOIN BDTemuColombia.dbo.Ventas v ON dv.venta_id = v.id
    INNER JOIN DimTiempo t ON CONVERT(date, v.fecha) = t.Fecha
    -- Las siguientes dimensiones ya deben tener los IDs alineados con las tablas fuente
WHERE
    EXISTS (SELECT 1 FROM DimProducto dp WHERE dp.ProductoID = dv.producto_id)
    AND EXISTS (SELECT 1 FROM DimCliente dc WHERE dc.ClienteID = v.cliente_id)
    AND EXISTS (SELECT 1 FROM DimEmpleado de WHERE de.EmpleadoID = v.empleado_id);

PRINT 'Tabla de hechos de Ventas cargada exitosamente.'

-- Carga de FactInventario
PRINT 'Cargando tabla de hechos de Inventario...'

INSERT INTO FactInventario (
    TiempoID,
    ProductoID,
    Cantidad,
    InventarioSourceID
)
SELECT 
    t.TiempoID,
    i.producto_id,
    i.cantidad,
    i.id AS InventarioSourceID
FROM 
    BDTemuColombia.dbo.Inventario i
    INNER JOIN DimTiempo t ON CONVERT(date, i.fecha_actualizacion) = t.Fecha
WHERE
    EXISTS (SELECT 1 FROM DimProducto dp WHERE dp.ProductoID = i.producto_id);

PRINT 'Tabla de hechos de Inventario cargada exitosamente.'

-- Carga de FactEnvios
PRINT 'Cargando tabla de hechos de Envíos...'

INSERT INTO FactEnvios (
    TiempoID_FechaEnvio,
    TiempoID_FechaEstimadaEntrega,
    ProductoID,
    ClienteID,
    TransportistaID,
    UbicacionOrigenID,
    UbicacionDestinoID,
    EstadoEnvioID,
    MetodoEnvio,
    DuracionEstimada,
    CostoEnvio,
    OrdenEnvioSourceID,
    DetalleEnvioSourceID,
    RutaEnvioSourceID
)
SELECT 
    t_envio.TiempoID,
    t_entrega_est.TiempoID,
    dv.producto_id,
    v.cliente_id,
    r.transportista_id,
    origen.UbicacionID,
    destino.UbicacionID,
    CASE oe.estado_envio
        WHEN 'En preparación' THEN 1
        WHEN 'En tránsito' THEN 2
        WHEN 'Entregado' THEN 3
        ELSE 1 -- Valor por defecto
    END AS EstadoEnvioID,
    oe.metodo_envio,
    r.duracion_estimada,
    -- Costo de envío simulado basado en distancia y método de envío
    CASE oe.metodo_envio 
        WHEN 'Express' THEN r.duracion_estimada * 1000 + 20000
        ELSE r.duracion_estimada * 500 + 10000
    END AS CostoEnvio,
    oe.id AS OrdenEnvioSourceID,
    de.id AS DetalleEnvioSourceID,
    r.id AS RutaEnvioSourceID
FROM 
    BDTemuColombia.dbo.OrdenesEnvio oe
    INNER JOIN BDTemuColombia.dbo.Ventas v ON oe.venta_id = v.id
    INNER JOIN BDTemuColombia.dbo.DetalleVentas dv ON v.id = dv.venta_id
    INNER JOIN BDTemuColombia.dbo.DetallesEnvio de ON oe.id = de.orden_envio_id
    -- Seleccionar una ruta para el envío (simulación)
    INNER JOIN BDTemuColombia.dbo.RutasEnvio r ON 
        r.transportista_id = (oe.id % 50 + 1) -- Asignación aleatoria
    INNER JOIN DimTiempo t_envio ON CONVERT(date, oe.fecha_envio) = t_envio.Fecha
    -- Fecha estimada basada en duración estimada
    INNER JOIN DimTiempo t_entrega_est ON 
        CONVERT(date, DATEADD(HOUR, r.duracion_estimada, oe.fecha_envio)) = t_entrega_est.Fecha
    -- Ubicaciones
    INNER JOIN DimUbicacion origen ON origen.Ciudad = r.origen
    INNER JOIN DimUbicacion destino ON destino.Ciudad = de.ciudad
WHERE
    EXISTS (SELECT 1 FROM DimProducto dp WHERE dp.ProductoID = dv.producto_id)
    AND EXISTS (SELECT 1 FROM DimCliente dc WHERE dc.ClienteID = v.cliente_id)
    AND EXISTS (SELECT 1 FROM DimTransportista dt WHERE dt.TransportistaID = r.transportista_id);

-- Actualizar la duración real para envíos entregados (simulación)
UPDATE FactEnvios
SET 
    TiempoID_FechaEntrega = 
        CASE 
            WHEN EstadoEnvioID = 3 -- Entregado
                THEN (SELECT TOP 1 TiempoID FROM DimTiempo 
                     WHERE Fecha = DATEADD(DAY, CAST(RAND(CHECKSUM(NEWID())) * 5 AS INT), 
                           (SELECT TOP 1 Fecha FROM DimTiempo WHERE TiempoID = TiempoID_FechaEstimadaEntrega)))
            ELSE NULL
        END,
    DuracionReal = 
        CASE 
            WHEN EstadoEnvioID = 3 -- Entregado
                THEN DuracionEstimada + CAST(RAND(CHECKSUM(NEWID())) * 24 - 12 AS INT) -- +/- 12 horas
            ELSE NULL
        END;

PRINT 'Tabla de hechos de Envíos cargada exitosamente.'
PRINT 'Todas las tablas de hechos han sido cargadas exitosamente.'

GO
