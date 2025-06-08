-- =========================================================================
-- SCRIPT DE VALIDACIÓN DE DATOS DEL DATA WAREHOUSE
-- =========================================================================
-- Este script realiza comprobaciones completas de calidad e integridad de datos
-- en todas las tablas del Data Warehouse DW_TemuColombia
-- =========================================================================

USE DW_TemuColombia;
GO

-- Crear tabla para almacenar resultados de validación
IF OBJECT_ID('ValidacionDatosDW', 'U') IS NOT NULL
    DROP TABLE ValidacionDatosDW;
GO

CREATE TABLE ValidacionDatosDW (
    ValidacionID INT IDENTITY(1,1) PRIMARY KEY,
    FechaValidacion DATETIME DEFAULT GETDATE(),
    CategoriaValidacion VARCHAR(50) NOT NULL,
    TablaValidada VARCHAR(100) NOT NULL,
    ColumnaValidada VARCHAR(100) NULL,
    TipoValidacion VARCHAR(100) NOT NULL,
    ResultadoValidacion VARCHAR(20) NOT NULL, -- 'Éxito', 'Advertencia', 'Error'
    Descripcion VARCHAR(500) NOT NULL,
    RegistrosAfectados INT NULL,
    DetalleError VARCHAR(MAX) NULL
);
GO

-- =========================================================================
-- 1. VALIDAR INTEGRIDAD REFERENCIAL
-- =========================================================================

-- Verificar integridad referencial entre FactVentas y dimensiones
INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                               TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Integridad Referencial',
    'FactVentas',
    'TiempoID',
    'FK Validation',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Registros en FactVentas con TiempoID que no existe en DimTiempo',
    COUNT(*)
FROM FactVentas fv
WHERE NOT EXISTS (SELECT 1 FROM DimTiempo dt WHERE dt.TiempoID = fv.TiempoID);

INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                               TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Integridad Referencial',
    'FactVentas',
    'ProductoID',
    'FK Validation',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Registros en FactVentas con ProductoID que no existe en DimProducto',
    COUNT(*)
FROM FactVentas fv
WHERE NOT EXISTS (SELECT 1 FROM DimProducto dp WHERE dp.ProductoID = fv.ProductoID);

INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                               TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Integridad Referencial',
    'FactVentas',
    'ClienteID',
    'FK Validation',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Registros en FactVentas con ClienteID que no existe en DimCliente',
    COUNT(*)
FROM FactVentas fv
WHERE NOT EXISTS (SELECT 1 FROM DimCliente dc WHERE dc.ClienteID = fv.ClienteID);

-- Verificar integridad referencial para FactInventario
INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                               TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Integridad Referencial',
    'FactInventario',
    'ProductoID',
    'FK Validation',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Registros en FactInventario con ProductoID que no existe en DimProducto',
    COUNT(*)
FROM FactInventario fi
WHERE NOT EXISTS (SELECT 1 FROM DimProducto dp WHERE dp.ProductoID = fi.ProductoID);

-- Verificar integridad referencial para FactEnvios
INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                               TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Integridad Referencial',
    'FactEnvios',
    'ClienteID',
    'FK Validation',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Registros en FactEnvios con ClienteID que no existe en DimCliente',
    COUNT(*)
FROM FactEnvios fe
WHERE NOT EXISTS (SELECT 1 FROM DimCliente dc WHERE dc.ClienteID = fe.ClienteID);

-- =========================================================================
-- 2. VALIDAR VALORES NULOS EN CAMPOS CRÍTICOS
-- =========================================================================

INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Completitud de Datos',
    'DimProducto',
    'NombreProducto',
    'NULL Check',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Productos sin nombre especificado',
    COUNT(*)
FROM DimProducto
WHERE NombreProducto IS NULL OR TRIM(NombreProducto) = '';

INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Completitud de Datos',
    'DimCliente',
    'NombreCliente',
    'NULL Check',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Clientes sin nombre especificado',
    COUNT(*)
FROM DimCliente
WHERE NombreCliente IS NULL OR TRIM(NombreCliente) = '';

INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Completitud de Datos',
    'FactVentas',
    'Cantidad',
    'NULL Check',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Ventas con cantidad no especificada',
    COUNT(*)
FROM FactVentas
WHERE Cantidad IS NULL;

-- =========================================================================
-- 3. VALIDAR RANGOS Y LÓGICA DE NEGOCIO
-- =========================================================================

-- Verificar cantidades negativas en ventas
INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Lógica de Negocio',
    'FactVentas',
    'Cantidad',
    'Range Check',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Ventas con cantidades negativas o cero',
    COUNT(*)
FROM FactVentas
WHERE Cantidad <= 0;

-- Verificar precios negativos en ventas
INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Lógica de Negocio',
    'FactVentas',
    'PrecioUnitario',
    'Range Check',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Ventas con precios negativos o cero',
    COUNT(*)
FROM FactVentas
WHERE PrecioUnitario <= 0;

-- Verificar cantidades negativas en inventario
INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Lógica de Negocio',
    'FactInventario',
    'Cantidad',
    'Range Check',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Advertencia'
        ELSE 'Éxito'
    END,
    'Inventarios con cantidades negativas',
    COUNT(*)
FROM FactInventario
WHERE Cantidad < 0;

-- Verificar coherencia de fechas en envíos
INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Lógica de Negocio',
    'DimTiempo/FactEnvios',
    'Fechas',
    'Date Logic',
    CASE 
        WHEN COUNT(*) > 0 THEN 'Error'
        ELSE 'Éxito'
    END,
    'Envíos donde la fecha de entrega es anterior a la fecha de envío',
    COUNT(*)
FROM FactEnvios fe
JOIN DimTiempo dt_envio ON fe.TiempoID_FechaEnvio = dt_envio.TiempoID
JOIN DimTiempo dt_entrega ON fe.TiempoID_FechaEntrega = dt_entrega.TiempoID
WHERE dt_entrega.Fecha < dt_envio.Fecha;

-- =========================================================================
-- 4. VALIDAR DUPLICADOS
-- =========================================================================

-- Verificar posibles duplicados en dimensiones
DECLARE @duplicates TABLE (
    TableName VARCHAR(100),
    ColumnName VARCHAR(100),
    DuplicateCount INT
);

INSERT INTO @duplicates (TableName, ColumnName, DuplicateCount)
SELECT 
    'DimProducto',
    'NombreProducto',
    COUNT(*) - COUNT(DISTINCT NombreProducto)
FROM DimProducto;

INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Calidad de Datos',
    TableName,
    ColumnName,
    'Duplicate Check',
    CASE 
        WHEN DuplicateCount > 0 THEN 'Advertencia'
        ELSE 'Éxito'
    END,
    'Posibles valores duplicados en nombres de producto',
    DuplicateCount
FROM @duplicates
WHERE TableName = 'DimProducto';

-- =========================================================================
-- 5. VALIDAR ESTADÍSTICAS DE DATOS
-- =========================================================================

-- Validar estadísticas de ventas
INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados)
SELECT 
    'Estadísticas',
    'FactVentas',
    'Total',
    'Stats Check',
    CASE 
        WHEN AVG(Total) > 10000000 OR AVG(Total) < 10000 THEN 'Advertencia'
        ELSE 'Éxito'
    END,
    'Verificación de promedio de ventas: ' + CAST(AVG(Total) AS VARCHAR(50)),
    COUNT(*)
FROM FactVentas;

-- =========================================================================
-- 6. VALIDAR DISTRIBUCIÓN DE DATOS
-- =========================================================================

-- Verificar distribución de categorías de productos
INSERT INTO ValidacionDatosDW (CategoriaValidacion, TablaValidada, ColumnaValidada, 
                              TipoValidacion, ResultadoValidacion, Descripcion, RegistrosAfectados, DetalleError)
SELECT 
    'Distribución de Datos',
    'DimProducto',
    'Categoria',
    'Distribution Check',
    'Informativo',
    'Distribución de productos por categoría',
    COUNT(*),
    'Categoría: ' + Categoria + ' - Cantidad: ' + CAST(COUNT(*) AS VARCHAR(10))
FROM DimProducto
GROUP BY Categoria;

-- =========================================================================
-- 7. GENERAR RESUMEN DE VALIDACIÓN
-- =========================================================================

-- Mostrar resumen de validación
SELECT 
    'Resumen de Validación de Datos (Fecha: ' + CONVERT(VARCHAR, GETDATE(), 120) + ')' AS Título;

SELECT 
    ResultadoValidacion AS 'Resultado',
    COUNT(*) AS 'Cantidad de Validaciones'
FROM ValidacionDatosDW
GROUP BY ResultadoValidacion
ORDER BY 
    CASE 
        WHEN ResultadoValidacion = 'Error' THEN 1
        WHEN ResultadoValidacion = 'Advertencia' THEN 2
        WHEN ResultadoValidacion = 'Informativo' THEN 3
        ELSE 4
    END;

-- Mostrar validaciones con errores
SELECT 
    'ERRORES ENCONTRADOS:' AS Título
WHERE EXISTS (SELECT 1 FROM ValidacionDatosDW WHERE ResultadoValidacion = 'Error');

SELECT 
    TablaValidada AS 'Tabla',
    ColumnaValidada AS 'Columna',
    TipoValidacion AS 'Tipo de Validación',
    Descripcion AS 'Descripción del Error',
    RegistrosAfectados AS 'Registros Afectados'
FROM ValidacionDatosDW
WHERE ResultadoValidacion = 'Error'
ORDER BY RegistrosAfectados DESC;

-- Mostrar validaciones con advertencias
SELECT 
    'ADVERTENCIAS ENCONTRADAS:' AS Título
WHERE EXISTS (SELECT 1 FROM ValidacionDatosDW WHERE ResultadoValidacion = 'Advertencia');

SELECT 
    TablaValidada AS 'Tabla',
    ColumnaValidada AS 'Columna',
    TipoValidacion AS 'Tipo de Validación',
    Descripcion AS 'Descripción de la Advertencia',
    RegistrosAfectados AS 'Registros Afectados'
FROM ValidacionDatosDW
WHERE ResultadoValidacion = 'Advertencia'
ORDER BY RegistrosAfectados DESC;

-- =========================================================================
-- 8. MOSTRAR CONTEO DE REGISTROS POR TABLA
-- =========================================================================

-- Mostrar el número de registros por tabla
SELECT
    'CONTEO DE REGISTROS POR TABLA:' AS Título;

SELECT * FROM (
    SELECT 
        'Dimensiones' AS TipoTabla,
        'DimTiempo' AS NombreTabla,
        COUNT(*) AS NumeroRegistros
    FROM DimTiempo
    UNION ALL
    SELECT 
        'Dimensiones',
        'DimProducto',
        COUNT(*)
    FROM DimProducto
    UNION ALL
    SELECT 
        'Dimensiones',
        'DimCliente',
        COUNT(*)
    FROM DimCliente
    UNION ALL
    SELECT 
        'Dimensiones',
        'DimEmpleado',
        COUNT(*)
    FROM DimEmpleado
    UNION ALL
    SELECT 
        'Dimensiones',
        'DimProveedor',
        COUNT(*)
    FROM DimProveedor
    UNION ALL
    SELECT 
        'Dimensiones',
        'DimTransportista',
        COUNT(*)
    FROM DimTransportista
    UNION ALL
    SELECT 
        'Dimensiones',
        'DimUbicacion',
        COUNT(*)
    FROM DimUbicacion
    UNION ALL
    SELECT 
        'Dimensiones',
        'DimEstadoEnvio',
        COUNT(*)
    FROM DimEstadoEnvio
    UNION ALL
    SELECT 
        'Hechos',
        'FactVentas',
        COUNT(*)
    FROM FactVentas
    UNION ALL
    SELECT 
        'Hechos',
        'FactInventario',
        COUNT(*)
    FROM FactInventario
    UNION ALL
    SELECT 
        'Hechos',
        'FactEnvios',
        COUNT(*)
    FROM FactEnvios
) AS TablaConteo
ORDER BY 
    CASE TipoTabla
        WHEN 'Dimensiones' THEN 1
        WHEN 'Hechos' THEN 2
        ELSE 3
    END,
    NombreTabla;

-- =========================================================================
-- 9. MOSTRAR EJEMPLOS DE DATOS POR TABLA
-- =========================================================================

-- Mostrar ejemplos de datos de cada tabla principal
SELECT 'EJEMPLOS DE DATOS - DIMENSIONES:' AS Título;

-- Mostrar ejemplo de DimProducto
SELECT 'DimProducto - Ejemplo (Top 3 registros):' AS 'Tabla';
SELECT TOP 3 * FROM DimProducto;

-- Mostrar ejemplo de DimCliente
SELECT 'DimCliente - Ejemplo (Top 3 registros):' AS 'Tabla';
SELECT TOP 3 * FROM DimCliente;

-- Mostrar ejemplo de DimTiempo
SELECT 'DimTiempo - Ejemplo (Top 3 registros):' AS 'Tabla';
SELECT TOP 3 * FROM DimTiempo;

SELECT 'EJEMPLOS DE DATOS - HECHOS:' AS Título;

-- Mostrar ejemplo de FactVentas
SELECT 'FactVentas - Ejemplo (Top 3 registros):' AS 'Tabla';
SELECT TOP 3 * FROM FactVentas;

-- Mostrar ejemplo de FactInventario
SELECT 'FactInventario - Ejemplo (Top 3 registros):' AS 'Tabla';
SELECT TOP 3 * FROM FactInventario;

-- Mostrar ejemplo de FactEnvios
SELECT 'FactEnvios - Ejemplo (Top 3 registros):' AS 'Tabla';
SELECT TOP 3 * FROM FactEnvios;

-- =========================================================================
-- 10. VALIDACIÓN DE MÉTRICAS DE RENDIMIENTO
-- =========================================================================

-- Registrar datos estadísticos principales para análisis de rendimiento
SELECT 'MÉTRICAS DE RENDIMIENTO Y ESTADÍSTICAS:' AS Título;

-- Estadísticas de ventas por producto (Top 5)
SELECT 'TOP 5 - PRODUCTOS MÁS VENDIDOS' AS 'Informe';
SELECT TOP 5
    dp.ProductoID,
    dp.NombreProducto,
    dp.Categoria,
    COUNT(fv.VentaID) AS NumeroVentas,
    SUM(fv.Cantidad) AS UnidadesVendidas,
    SUM(fv.Total) AS TotalVentas
FROM FactVentas fv
JOIN DimProducto dp ON fv.ProductoID = dp.ProductoID
GROUP BY dp.ProductoID, dp.NombreProducto, dp.Categoria
ORDER BY SUM(fv.Total) DESC;

-- Estadísticas de ventas por cliente (Top 5)
SELECT 'TOP 5 - CLIENTES CON MAYOR COMPRA' AS 'Informe';
SELECT TOP 5
    dc.ClienteID,
    dc.NombreCliente,
    COUNT(fv.VentaID) AS NumeroCompras,
    SUM(fv.Total) AS TotalCompras
FROM FactVentas fv
JOIN DimCliente dc ON fv.ClienteID = dc.ClienteID
GROUP BY dc.ClienteID, dc.NombreCliente
ORDER BY SUM(fv.Total) DESC;

-- Análisis de envíos por estado
SELECT 'DISTRIBUCIÓN DE ENVÍOS POR ESTADO' AS 'Informe';
SELECT
    dee.NombreEstado,
    COUNT(fe.EnvioID) AS NumeroEnvios,
    AVG(DATEDIFF(DAY, dt_envio.Fecha, dt_entrega.Fecha)) AS TiempoPromedioEntrega
FROM FactEnvios fe
JOIN DimEstadoEnvio dee ON fe.EstadoEnvioID = dee.EstadoEnvioID
JOIN DimTiempo dt_envio ON fe.TiempoID_FechaEnvio = dt_envio.TiempoID
JOIN DimTiempo dt_entrega ON fe.TiempoID_FechaEntrega = dt_entrega.TiempoID
GROUP BY dee.NombreEstado
ORDER BY COUNT(fe.EnvioID) DESC;

-- =========================================================================
-- FIN DEL SCRIPT DE VALIDACIÓN
-- =========================================================================
