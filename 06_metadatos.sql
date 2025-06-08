-- SCRIPT PARA GENERACIÓN DE METADATOS DEL DATA WAREHOUSE
-- Este script crea tablas para almacenar metadatos del DW

USE DW_TemuColombia
GO

-- =============================================
-- TABLAS DE METADATOS
-- =============================================

-- Tabla para metadatos del Data Warehouse
IF OBJECT_ID('MetadatosDW', 'U') IS NULL
BEGIN
    CREATE TABLE MetadatosDW (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        NombreTabla NVARCHAR(100) NOT NULL,
        TipoTabla NVARCHAR(20) NOT NULL, -- 'Dimensión' o 'Hecho'
        Descripcion NVARCHAR(MAX),
        CantidadRegistros BIGINT,
        EspacioOcupadoKB DECIMAL(18, 2),
        FechaCreacion DATETIME,
        UltimaActualizacion DATETIME,
        DependenciasTablas NVARCHAR(MAX), -- Tablas de las que depende
        TablasGrano NVARCHAR(MAX) -- Nivel de detalle/granularidad
    );
END
GO

-- Tabla para metadatos de columnas
IF OBJECT_ID('MetadatosColumnas', 'U') IS NULL
BEGIN
    CREATE TABLE MetadatosColumnas (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        NombreTabla NVARCHAR(100) NOT NULL,
        NombreColumna NVARCHAR(100) NOT NULL,
        TipoDato NVARCHAR(50),
        EsPrimaryKey BIT,
        EsForeignKey BIT,
        TablaReferenciada NVARCHAR(100), -- Si es FK, tabla a la que referencia
        ColumnaReferenciada NVARCHAR(100), -- Si es FK, columna a la que referencia
        PermiteNulos BIT,
        TieneIndice BIT,
        Descripcion NVARCHAR(MAX),
        PorcentajeNulos DECIMAL(5, 2), -- % de valores nulos en la columna
        CardinalidadUnica BIGINT, -- Cantidad de valores únicos
        ValorMinimo NVARCHAR(255), -- Para campos numéricos/fecha
        ValorMaximo NVARCHAR(255) -- Para campos numéricos/fecha
    );
END
GO

-- =============================================
-- PROCEDIMIENTOS PARA ACTUALIZAR METADATOS
-- =============================================

-- Procedimiento para obtener metadatos de tablas
CREATE PROCEDURE sp_ActualizarMetadatosTablas
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Limpiar tabla antes de insertar nuevos metadatos
    TRUNCATE TABLE MetadatosDW;
    
    -- Insertar metadatos de tablas del DW
    INSERT INTO MetadatosDW (
        NombreTabla, 
        TipoTabla, 
        Descripcion, 
        CantidadRegistros,
        EspacioOcupadoKB,
        FechaCreacion, 
        UltimaActualizacion,
        DependenciasTablas,
        TablasGrano
    )
    SELECT 
        t.name AS NombreTabla,
        CASE 
            WHEN t.name LIKE 'Dim%' THEN 'Dimensión'
            WHEN t.name LIKE 'Fact%' THEN 'Hecho'
            ELSE 'Otra'
        END AS TipoTabla,
        CASE 
            WHEN t.name = 'DimTiempo' THEN 'Dimensión de tiempo que contiene jerarquías temporales como año, trimestre, mes, semana, día.'
            WHEN t.name = 'DimProducto' THEN 'Dimensión de productos con atributos como nombre, descripción, categoría y precio.'
            WHEN t.name = 'DimCliente' THEN 'Dimensión de clientes con información de contacto y ubicación.'
            WHEN t.name = 'DimEmpleado' THEN 'Dimensión de empleados con información de cargo y contacto.'
            WHEN t.name = 'DimProveedor' THEN 'Dimensión de proveedores con información de contacto.'
            WHEN t.name = 'DimTransportista' THEN 'Dimensión de empresas transportadoras con información de contacto.'
            WHEN t.name = 'DimUbicacion' THEN 'Dimensión de ubicaciones geográficas con ciudad, código postal, país y región.'
            WHEN t.name = 'DimEstadoEnvio' THEN 'Dimensión de estados posibles para los envíos.'
            WHEN t.name = 'FactVentas' THEN 'Tabla de hechos que almacena las transacciones de ventas con cantidades y montos.'
            WHEN t.name = 'FactInventario' THEN 'Tabla de hechos que almacena los niveles de inventario a lo largo del tiempo.'
            WHEN t.name = 'FactEnvios' THEN 'Tabla de hechos que almacena información sobre los envíos realizados.'
            ELSE 'Descripción pendiente'
        END AS Descripcion,
        p.rows AS CantidadRegistros,
        (SUM(a.total_pages) * 8) AS EspacioOcupadoKB,
        COALESCE(CAST(MIN(cr.create_date) AS DATETIME), GETDATE()) AS FechaCreacion,
        COALESCE(CAST(MAX(m.modify_date) AS DATETIME), GETDATE()) AS UltimaActualizacion,
        CASE 
            WHEN t.name = 'FactVentas' THEN 'DimTiempo, DimProducto, DimCliente, DimEmpleado'
            WHEN t.name = 'FactInventario' THEN 'DimTiempo, DimProducto'
            WHEN t.name = 'FactEnvios' THEN 'DimTiempo, DimProducto, DimCliente, DimTransportista, DimUbicacion, DimEstadoEnvio'
            ELSE NULL
        END AS DependenciasTablas,
        CASE 
            WHEN t.name = 'FactVentas' THEN 'A nivel de línea de detalle de venta'
            WHEN t.name = 'FactInventario' THEN 'A nivel de producto-fecha'
            WHEN t.name = 'FactEnvios' THEN 'A nivel de envío individual'
            ELSE NULL
        END AS TablasGrano
    FROM 
        sys.tables t
        INNER JOIN sys.indexes i ON t.object_id = i.object_id
        INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
        INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
        LEFT JOIN sys.objects m ON t.object_id = m.object_id
        LEFT JOIN sys.objects cr ON t.object_id = cr.object_id
    WHERE 
        t.is_ms_shipped = 0
    GROUP BY 
        t.name, p.rows;
        
    PRINT 'Metadatos de tablas actualizados';
END
GO

-- Procedimiento para obtener metadatos de columnas
CREATE PROCEDURE sp_ActualizarMetadatosColumnas
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Limpiar tabla antes de insertar nuevos metadatos
    TRUNCATE TABLE MetadatosColumnas;
    
    -- Insertar metadatos de columnas
    INSERT INTO MetadatosColumnas (
        NombreTabla, 
        NombreColumna, 
        TipoDato, 
        EsPrimaryKey, 
        EsForeignKey, 
        TablaReferenciada, 
        ColumnaReferenciada, 
        PermiteNulos, 
        TieneIndice,
        Descripcion
    )
    SELECT 
        OBJECT_NAME(c.object_id) AS NombreTabla,
        c.name AS NombreColumna,
        t.name + 
            CASE 
                WHEN t.name IN ('varchar', 'nvarchar', 'char', 'nchar') 
                    THEN '(' + 
                        CASE 
                            WHEN c.max_length = -1 THEN 'MAX' 
                            WHEN t.name IN ('nvarchar', 'nchar') THEN CAST(c.max_length/2 AS VARCHAR(10))
                            ELSE CAST(c.max_length AS VARCHAR(10)) 
                        END + ')'
                WHEN t.name IN ('decimal', 'numeric') 
                    THEN '(' + CAST(c.precision AS VARCHAR(10)) + ',' + CAST(c.scale AS VARCHAR(10)) + ')'
                ELSE ''
            END AS TipoDato,
        CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS EsPrimaryKey,
        CASE WHEN fk.parent_column_id IS NOT NULL THEN 1 ELSE 0 END AS EsForeignKey,
        OBJECT_NAME(fk.referenced_object_id) AS TablaReferenciada,
        COL_NAME(fk.referenced_object_id, fk.referenced_column_id) AS ColumnaReferenciada,
        c.is_nullable AS PermiteNulos,
        CASE WHEN i.column_id IS NOT NULL THEN 1 ELSE 0 END AS TieneIndice,
        CASE 
            -- Dimensión Tiempo
            WHEN OBJECT_NAME(c.object_id) = 'DimTiempo' AND c.name = 'Fecha' THEN 'Fecha en formato DATE'
            WHEN OBJECT_NAME(c.object_id) = 'DimTiempo' AND c.name = 'Anio' THEN 'Año de la fecha'
            WHEN OBJECT_NAME(c.object_id) = 'DimTiempo' AND c.name = 'Trimestre' THEN 'Número de trimestre (1-4)'
            WHEN OBJECT_NAME(c.object_id) = 'DimTiempo' AND c.name = 'Mes' THEN 'Número de mes (1-12)'
            WHEN OBJECT_NAME(c.object_id) = 'DimTiempo' AND c.name = 'NombreMes' THEN 'Nombre del mes'
            WHEN OBJECT_NAME(c.object_id) = 'DimTiempo' AND c.name = 'DiaSemana' THEN 'Número del día de la semana (1-7)'
            WHEN OBJECT_NAME(c.object_id) = 'DimTiempo' AND c.name = 'EsFestivo' THEN 'Indicador si es día festivo'
            
            -- Dimensión Producto
            WHEN OBJECT_NAME(c.object_id) = 'DimProducto' AND c.name = 'ProductoID' THEN 'ID del producto en el sistema fuente'
            WHEN OBJECT_NAME(c.object_id) = 'DimProducto' AND c.name = 'ProductoKey' THEN 'Clave de negocio del producto'
            WHEN OBJECT_NAME(c.object_id) = 'DimProducto' AND c.name = 'NombreProducto' THEN 'Nombre comercial del producto'
            WHEN OBJECT_NAME(c.object_id) = 'DimProducto' AND c.name = 'Categoria' THEN 'Categoría del producto'
            WHEN OBJECT_NAME(c.object_id) = 'DimProducto' AND c.name = 'PrecioActual' THEN 'Precio actual del producto'
            
            -- Fact Ventas
            WHEN OBJECT_NAME(c.object_id) = 'FactVentas' AND c.name = 'TiempoID' THEN 'Clave foránea a dimensión tiempo'
            WHEN OBJECT_NAME(c.object_id) = 'FactVentas' AND c.name = 'ProductoID' THEN 'Clave foránea a dimensión producto'
            WHEN OBJECT_NAME(c.object_id) = 'FactVentas' AND c.name = 'ClienteID' THEN 'Clave foránea a dimensión cliente'
            WHEN OBJECT_NAME(c.object_id) = 'FactVentas' AND c.name = 'Cantidad' THEN 'Cantidad vendida del producto'
            WHEN OBJECT_NAME(c.object_id) = 'FactVentas' AND c.name = 'Total' THEN 'Valor total de la venta (precio * cantidad)'
            
            ELSE 'Descripción pendiente'
        END AS Descripcion
    FROM 
        sys.columns c
        INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
        LEFT JOIN sys.indexes pk_idx ON c.object_id = pk_idx.object_id AND pk_idx.is_primary_key = 1
        LEFT JOIN sys.index_columns pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id AND pk.index_id = pk_idx.index_id
        LEFT JOIN sys.foreign_key_columns fk ON c.object_id = fk.parent_object_id AND c.column_id = fk.parent_column_id
        LEFT JOIN sys.index_columns i ON c.object_id = i.object_id AND c.column_id = i.column_id
    WHERE 
        OBJECTPROPERTY(c.object_id, 'IsUserTable') = 1;
    
    PRINT 'Metadatos de columnas actualizados';
END
GO

-- =============================================
-- EJECUCION DE PROCEDIMIENTOS DE METADATOS
-- =============================================

-- Ejecutar procedimientos para actualizar metadatos
EXEC sp_ActualizarMetadatosTablas;
EXEC sp_ActualizarMetadatosColumnas;

-- Consulta para verificar metadatos de tablas
PRINT 'Metadatos de tablas:'
SELECT NombreTabla, TipoTabla, CantidadRegistros, EspacioOcupadoKB, UltimaActualizacion FROM MetadatosDW;

-- Consulta para verificar metadatos de columnas
PRINT 'Metadatos de columnas de las tablas de hechos (primeras 10):'
SELECT TOP 10 NombreTabla, NombreColumna, TipoDato, EsPrimaryKey, EsForeignKey, TablaReferenciada, Descripcion
FROM MetadatosColumnas
WHERE NombreTabla LIKE 'Fact%'
ORDER BY NombreTabla, NombreColumna;

PRINT 'Generación de metadatos completada'
GO
