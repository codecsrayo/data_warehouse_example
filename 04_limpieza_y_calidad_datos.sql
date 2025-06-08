-- SCRIPT PARA LIMPIEZA Y CALIDAD DE DATOS
-- Este script contiene procedimientos para limpieza y verificación de calidad de datos

USE DW_TemuColombia
GO

-- =============================================
-- LIMPIEZA DE DATOS
-- =============================================

PRINT 'Iniciando procesos de limpieza y calidad de datos...'

-- Procedimiento para normalizar categorías de productos
CREATE PROCEDURE sp_LimpiarCategoriasProductos
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Estandarizar nombres de categorías (eliminar acentos, minúsculas/mayúsculas inconsistentes)
    UPDATE DimProducto
    SET Categoria = 'Electrónicos'
    WHERE Categoria LIKE '%lectron%' OR Categoria LIKE '%electron%';
    
    UPDATE DimProducto
    SET Categoria = 'Electrodomésticos'
    WHERE Categoria LIKE '%lectrodom%' OR Categoria LIKE '%lectrod%';
    
    UPDATE DimProducto
    SET Categoria = 'Muebles'
    WHERE Categoria LIKE '%mueb%' OR Categoria LIKE '%mobil%';
    
    UPDATE DimProducto
    SET Categoria = 'Celulares'
    WHERE Categoria LIKE '%celul%' OR Categoria LIKE '%movil%' OR Categoria LIKE '%móvil%' OR Categoria LIKE '%phone%';
    
    UPDATE DimProducto
    SET Categoria = 'Computadores'
    WHERE Categoria LIKE '%comp%' OR Categoria LIKE '%laptop%' OR Categoria LIKE '%pc%';
    
    PRINT 'Categorías de productos estandarizadas';
END
GO

-- Procedimiento para limpiar datos de clientes
CREATE PROCEDURE sp_LimpiarDatosClientes
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Normalizar formatos de correo electrónico
    UPDATE DimCliente
    SET Email = LOWER(Email);
    
    -- Normalizar números telefónicos (eliminar caracteres no numéricos)
    UPDATE DimCliente
    SET Telefono = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Telefono, ' ', ''), '-', ''), '(', ''), ')', ''), '.', '');
    
    -- Normalizar nombres de ciudades (corregir erratas comunes)
    UPDATE DimCliente
    SET Ciudad = 'Bogotá'
    WHERE Ciudad LIKE '%bogot%' OR Ciudad LIKE '%bogota%' OR Ciudad LIKE '%bta%';
    
    UPDATE DimCliente
    SET Ciudad = 'Medellín'
    WHERE Ciudad LIKE '%medell%' OR Ciudad LIKE '%medellin%';
    
    UPDATE DimCliente
    SET Ciudad = 'Cali'
    WHERE Ciudad = 'cali' OR Ciudad = 'CALI' OR Ciudad LIKE '%santiago de cali%';
    
    UPDATE DimCliente
    SET Ciudad = 'Barranquilla'
    WHERE Ciudad LIKE '%barranq%';
    
    UPDATE DimCliente
    SET Ciudad = 'Cartagena'
    WHERE Ciudad LIKE '%cartag%';
    
    PRINT 'Datos de clientes normalizados';
END
GO

-- Procedimiento para detectar y corregir anomalías en datos numéricos
CREATE PROCEDURE sp_CorregirAnomaliasDatosNumericos
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Corregir precios anormalmente bajos o altos
    UPDATE DimProducto
    SET PrecioActual = 50000
    WHERE PrecioActual < 1000 AND Categoria = 'Electrónicos';
    
    UPDATE DimProducto
    SET PrecioActual = 5000000
    WHERE PrecioActual > 10000000;
    
    -- Corregir cantidades negativas o anormalmente altas en inventario
    UPDATE FactInventario
    SET Cantidad = 0
    WHERE Cantidad < 0;
    
    UPDATE FactInventario
    SET Cantidad = 100
    WHERE Cantidad > 1000;
    
    -- Corregir valores extremos en duraciones de envío
    UPDATE FactEnvios
    SET DuracionEstimada = 72
    WHERE DuracionEstimada > 168; -- Más de 7 días
    
    UPDATE FactEnvios
    SET DuracionReal = DuracionEstimada
    WHERE DuracionReal IS NOT NULL AND (DuracionReal < 1 OR DuracionReal > 240); -- Menos de 1 hora o más de 10 días
    
    PRINT 'Anomalías en datos numéricos corregidas';
END
GO

-- Procedimiento para detectar y marcar datos duplicados
CREATE PROCEDURE sp_DetectarDuplicados
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Crear tabla temporal para almacenar IDs de registros duplicados
    IF OBJECT_ID('tempdb..#Duplicados') IS NOT NULL
        DROP TABLE #Duplicados;
        
    CREATE TABLE #Duplicados (
        TablaNombre NVARCHAR(100),
        CampoID NVARCHAR(100),
        ValorID INT,
        Observacion NVARCHAR(255)
    );
    
    -- Detectar clientes con mismo email
    INSERT INTO #Duplicados
    SELECT 
        'DimCliente',
        'ClienteID',
        ClienteID,
        'Email duplicado: ' + Email
    FROM DimCliente
    WHERE Email IN (
        SELECT Email
        FROM DimCliente
        WHERE Email IS NOT NULL AND Email <> ''
        GROUP BY Email
        HAVING COUNT(*) > 1
    );
    
    -- Detectar productos con nombre similar
    INSERT INTO #Duplicados
    SELECT 
        'DimProducto',
        'ProductoID',
        ProductoID,
        'Nombre similar: ' + NombreProducto
    FROM DimProducto p1
    WHERE EXISTS (
        SELECT 1
        FROM DimProducto p2
        WHERE p1.ProductoID <> p2.ProductoID
        AND p1.NombreProducto = p2.NombreProducto
    );
    
    -- Imprimir resultados
    SELECT * FROM #Duplicados;
    
    PRINT 'Detección de duplicados completada';
END
GO

-- Procedimiento para verificar integridad referencial
CREATE PROCEDURE sp_VerificarIntegridadReferencial
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErroresIntegridad TABLE (
        TablaOrigen NVARCHAR(100),
        CampoOrigen NVARCHAR(100),
        ValorCampo INT,
        TablaDestino NVARCHAR(100),
        Observacion NVARCHAR(255)
    );
    
    -- Verificar integridad entre FactVentas y DimProducto
    INSERT INTO @ErroresIntegridad
    SELECT 
        'FactVentas',
        'ProductoID',
        ProductoID,
        'DimProducto',
        'ProductoID no existe en DimProducto'
    FROM FactVentas
    WHERE ProductoID NOT IN (SELECT ProductoID FROM DimProducto);
    
    -- Verificar integridad entre FactVentas y DimCliente
    INSERT INTO @ErroresIntegridad
    SELECT 
        'FactVentas',
        'ClienteID',
        ClienteID,
        'DimCliente',
        'ClienteID no existe en DimCliente'
    FROM FactVentas
    WHERE ClienteID NOT IN (SELECT ClienteID FROM DimCliente);
    
    -- Verificar integridad entre FactInventario y DimProducto
    INSERT INTO @ErroresIntegridad
    SELECT 
        'FactInventario',
        'ProductoID',
        ProductoID,
        'DimProducto',
        'ProductoID no existe en DimProducto'
    FROM FactInventario
    WHERE ProductoID NOT IN (SELECT ProductoID FROM DimProducto);
    
    -- Verificar integridad entre FactEnvios y dimensiones
    INSERT INTO @ErroresIntegridad
    SELECT 
        'FactEnvios',
        'ProductoID',
        ProductoID,
        'DimProducto',
        'ProductoID no existe en DimProducto'
    FROM FactEnvios
    WHERE ProductoID NOT IN (SELECT ProductoID FROM DimProducto);
    
    INSERT INTO @ErroresIntegridad
    SELECT 
        'FactEnvios',
        'ClienteID',
        ClienteID,
        'DimCliente',
        'ClienteID no existe en DimCliente'
    FROM FactEnvios
    WHERE ClienteID NOT IN (SELECT ClienteID FROM DimCliente);
    
    -- Imprimir resultados
    SELECT * FROM @ErroresIntegridad;
    
    -- Corregir errores si es necesario (en este caso, eliminamos registros huérfanos)
    DELETE FROM FactVentas
    WHERE ProductoID NOT IN (SELECT ProductoID FROM DimProducto)
    OR ClienteID NOT IN (SELECT ClienteID FROM DimCliente);
    
    DELETE FROM FactInventario
    WHERE ProductoID NOT IN (SELECT ProductoID FROM DimProducto);
    
    DELETE FROM FactEnvios
    WHERE ProductoID NOT IN (SELECT ProductoID FROM DimProducto)
    OR ClienteID NOT IN (SELECT ClienteID FROM DimCliente);
    
    PRINT 'Verificación y corrección de integridad referencial completada';
END
GO

-- Ejecutar procedimientos de limpieza y calidad
EXEC sp_LimpiarCategoriasProductos;
EXEC sp_LimpiarDatosClientes;
EXEC sp_CorregirAnomaliasDatosNumericos;
EXEC sp_DetectarDuplicados;
EXEC sp_VerificarIntegridadReferencial;

PRINT 'Proceso de limpieza y calidad de datos completado exitosamente';
GO
