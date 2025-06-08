-- SCRIPT PARA POBLAR LAS TABLAS DE DIMENSIONES
-- Este script realiza la carga inicial de datos en las tablas de dimensión

USE DW_TemuColombia
GO

-- =============================================
-- CARGA DE DIMENSIONES
-- =============================================

-- Carga de DimTiempo (Generación de tabla de tiempo para 5 años)
-- Desde el año pasado hasta 4 años en el futuro
PRINT 'Cargando dimensión de Tiempo...'
DECLARE @FechaInicio DATE = DATEADD(yy, -1, GETDATE())
DECLARE @FechaFin DATE = DATEADD(yy, 4, GETDATE())
DECLARE @FechaActual DATE = @FechaInicio

-- Truncar la tabla si ya tiene datos
TRUNCATE TABLE DimTiempo

WHILE @FechaActual <= @FechaFin
BEGIN
    INSERT INTO DimTiempo (
        Fecha,
        Anio,
        Trimestre,
        Mes,
        NombreMes,
        Semana,
        Dia,
        DiaSemana,
        NombreDiaSemana,
        EsFestivo,
        TrimestreNombre
    )
    VALUES (
        @FechaActual,
        YEAR(@FechaActual),
        DATEPART(qq, @FechaActual),
        MONTH(@FechaActual),
        DATENAME(mm, @FechaActual),
        DATEPART(ww, @FechaActual),
        DAY(@FechaActual),
        DATEPART(dw, @FechaActual),
        DATENAME(dw, @FechaActual),
        CASE 
            -- Definir días festivos colombianos como ejemplo
            -- Estos son simplificados, en un entorno real se tendría una tabla de festivos
            WHEN (MONTH(@FechaActual) = 1 AND DAY(@FechaActual) = 1) THEN 1 -- Año nuevo
            WHEN (MONTH(@FechaActual) = 5 AND DAY(@FechaActual) = 1) THEN 1 -- Día del trabajo
            WHEN (MONTH(@FechaActual) = 7 AND DAY(@FechaActual) = 20) THEN 1 -- Día de la independencia
            WHEN (MONTH(@FechaActual) = 12 AND DAY(@FechaActual) = 25) THEN 1 -- Navidad
            ELSE 0
        END,
        'Trimestre ' + CAST(DATEPART(qq, @FechaActual) AS VARCHAR(1)) + ' de ' + CAST(YEAR(@FechaActual) AS VARCHAR(4))
    )
    
    SET @FechaActual = DATEADD(dd, 1, @FechaActual)
END
PRINT 'Dimensión de Tiempo cargada exitosamente.'

-- Carga de DimEstadoEnvio
PRINT 'Cargando dimensión de Estado Envío...'
TRUNCATE TABLE DimEstadoEnvio
INSERT INTO DimEstadoEnvio (NombreEstado, Descripcion)
VALUES 
    ('En preparación', 'El pedido está siendo preparado para su envío'),
    ('En tránsito', 'El pedido se encuentra en ruta hacia su destino'),
    ('Entregado', 'El pedido ha sido entregado satisfactoriamente al cliente'),
    ('Retrasado', 'El envío está experimentando demoras'),
    ('Cancelado', 'El envío ha sido cancelado');
PRINT 'Dimensión de Estado Envío cargada exitosamente.'

-- Carga inicial de dimensiones desde base de datos OLTP (BDTemuColombia)
PRINT 'Iniciando carga de dimensiones desde base de datos OLTP...'

-- Carga de DimProducto desde OLTP
PRINT 'Cargando dimensión de Producto...'
INSERT INTO DimProducto (
    ProductoID, 
    ProductoKey, 
    NombreProducto, 
    Descripcion, 
    Categoria, 
    PrecioActual, 
    FechaCreacion
)
SELECT 
    p.id,
    'P-' + CAST(p.id AS NVARCHAR(10)),
    p.nombre,
    p.descripcion,
    p.categoria,
    p.precio,
    GETDATE()
FROM 
    BDTemuColombia.dbo.Productos p;
PRINT 'Dimensión de Producto cargada exitosamente.'

-- Carga de DimCliente desde OLTP
PRINT 'Cargando dimensión de Cliente...'
INSERT INTO DimCliente (
    ClienteID, 
    ClienteKey, 
    NombreCliente, 
    Email, 
    Telefono, 
    Direccion,
    Ciudad,
    CodigoPostal,
    FechaCreacion
)
SELECT 
    c.id,
    'C-' + CAST(c.id AS NVARCHAR(10)),
    c.nombre,
    c.email,
    c.telefono,
    c.direccion,
    -- Extraer ciudad de la dirección (simulación)
    CASE 
        WHEN c.id % 5 = 0 THEN 'Bogotá'
        WHEN c.id % 5 = 1 THEN 'Medellín'
        WHEN c.id % 5 = 2 THEN 'Cali'
        WHEN c.id % 5 = 3 THEN 'Barranquilla'
        ELSE 'Cartagena'
    END AS Ciudad,
    -- Simular código postal
    '1100' + RIGHT('00' + CAST((c.id % 99) AS NVARCHAR(2)), 2),
    GETDATE()
FROM 
    BDTemuColombia.dbo.Clientes c;
PRINT 'Dimensión de Cliente cargada exitosamente.'

-- Carga de DimEmpleado desde OLTP
PRINT 'Cargando dimensión de Empleado...'
INSERT INTO DimEmpleado (
    EmpleadoID, 
    EmpleadoKey, 
    NombreEmpleado, 
    Puesto, 
    Email, 
    Telefono,
    FechaContratacion,
    FechaCreacion
)
SELECT 
    e.id,
    'E-' + CAST(e.id AS NVARCHAR(10)),
    e.nombre,
    e.puesto,
    e.email,
    e.telefono,
    DATEADD(month, -CAST(RAND(CHECKSUM(NEWID())) * 36 AS INT), GETDATE()), -- Fecha contratación aleatoria en los últimos 3 años
    GETDATE()
FROM 
    BDTemuColombia.dbo.Empleados e;
PRINT 'Dimensión de Empleado cargada exitosamente.'

-- Carga de DimProveedor desde OLTP
PRINT 'Cargando dimensión de Proveedor...'
INSERT INTO DimProveedor (
    ProveedorID, 
    ProveedorKey, 
    NombreProveedor, 
    Contacto, 
    Telefono, 
    Direccion,
    FechaCreacion
)
SELECT 
    p.id,
    'PR-' + CAST(p.id AS NVARCHAR(10)),
    p.nombre,
    p.contacto,
    p.telefono,
    p.direccion,
    GETDATE()
FROM 
    BDTemuColombia.dbo.Proveedores p;
PRINT 'Dimensión de Proveedor cargada exitosamente.'

-- Carga de DimTransportista desde OLTP
PRINT 'Cargando dimensión de Transportista...'
INSERT INTO DimTransportista (
    TransportistaID, 
    TransportistaKey, 
    NombreTransportista, 
    Contacto, 
    Telefono, 
    Email,
    FechaCreacion
)
SELECT 
    t.id,
    'T-' + CAST(t.id AS NVARCHAR(10)),
    t.nombre,
    t.contacto,
    t.telefono,
    t.email,
    GETDATE()
FROM 
    BDTemuColombia.dbo.Transportistas t;
PRINT 'Dimensión de Transportista cargada exitosamente.'

-- Carga de DimUbicacion (ciudades únicas de envíos y rutas)
PRINT 'Cargando dimensión de Ubicación...'
INSERT INTO DimUbicacion (
    Ciudad,
    CodigoPostal,
    Pais,
    Region,
    FechaCreacion
)
SELECT DISTINCT 
    Ciudad, 
    CodigoPostal,
    'Colombia',
    -- Asignar regiones basado en la ciudad
    CASE 
        WHEN Ciudad = 'Bogotá' THEN 'Andina'
        WHEN Ciudad = 'Medellín' THEN 'Andina'
        WHEN Ciudad = 'Cali' THEN 'Pacífica'
        WHEN Ciudad = 'Barranquilla' THEN 'Caribe'
        WHEN Ciudad = 'Cartagena' THEN 'Caribe'
        ELSE 'Otra'
    END,
    GETDATE()
FROM 
    BDTemuColombia.dbo.DetallesEnvio;

-- Insertar ciudades únicas de rutas de envío
INSERT INTO DimUbicacion (
    Ciudad,
    Pais,
    Region,
    FechaCreacion
)
SELECT DISTINCT 
    r.origen as Ciudad, 
    'Colombia',
    -- Asignar regiones basado en la ciudad
    CASE 
        WHEN r.origen = 'Bogotá' THEN 'Andina'
        WHEN r.origen = 'Medellín' THEN 'Andina'
        WHEN r.origen = 'Cali' THEN 'Pacífica'
        WHEN r.origen = 'Barranquilla' THEN 'Caribe'
        WHEN r.origen = 'Cartagena' THEN 'Caribe'
        ELSE 'Otra'
    END,
    GETDATE()
FROM 
    BDTemuColombia.dbo.RutasEnvio r
WHERE 
    NOT EXISTS (
        SELECT 1 FROM DimUbicacion u WHERE u.Ciudad = r.origen
    );

INSERT INTO DimUbicacion (
    Ciudad,
    Pais,
    Region,
    FechaCreacion
)
SELECT DISTINCT 
    r.destino as Ciudad, 
    'Colombia',
    -- Asignar regiones basado en la ciudad
    CASE 
        WHEN r.destino = 'Bogotá' THEN 'Andina'
        WHEN r.destino = 'Medellín' THEN 'Andina'
        WHEN r.destino = 'Cali' THEN 'Pacífica'
        WHEN r.destino = 'Barranquilla' THEN 'Caribe'
        WHEN r.destino = 'Cartagena' THEN 'Caribe'
        ELSE 'Otra'
    END,
    GETDATE()
FROM 
    BDTemuColombia.dbo.RutasEnvio r
WHERE 
    NOT EXISTS (
        SELECT 1 FROM DimUbicacion u WHERE u.Ciudad = r.destino
    );

PRINT 'Dimensión de Ubicación cargada exitosamente.'
PRINT 'Todas las dimensiones han sido cargadas exitosamente.'

GO
