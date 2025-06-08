-- SCRIPT PARA CREAR EL DATA WAREHOUSE DE TEMU COLOMBIA
-- Este script crea la base de datos del data warehouse y define el modelo dimensional

-- Crear la base de datos para el data warehouse
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DW_TemuColombia')
CREATE DATABASE DW_TemuColombia
GO

USE DW_TemuColombia
GO

-- =============================================
-- TABLAS DE DIMENSIONES
-- =============================================

-- Dimensión Tiempo
CREATE TABLE DimTiempo (
    TiempoID INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATE NOT NULL,
    Anio INT NOT NULL,
    Trimestre INT NOT NULL,
    Mes INT NOT NULL,
    NombreMes NVARCHAR(20) NOT NULL,
    Semana INT NOT NULL,
    Dia INT NOT NULL,
    DiaSemana INT NOT NULL,
    NombreDiaSemana NVARCHAR(20) NOT NULL,
    EsFestivo BIT NOT NULL DEFAULT 0,
    TrimestreNombre NVARCHAR(20) NOT NULL
);

-- Dimensión Producto
CREATE TABLE DimProducto (
    ProductoID INT PRIMARY KEY,
    ProductoKey NVARCHAR(50) NOT NULL,
    NombreProducto NVARCHAR(255) NOT NULL,
    Descripcion NVARCHAR(MAX),
    Categoria NVARCHAR(100) NOT NULL,
    PrecioActual DECIMAL(18, 2) NOT NULL,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    FechaModificacion DATETIME,
    Activo BIT NOT NULL DEFAULT 1
);

-- Dimensión Cliente
CREATE TABLE DimCliente (
    ClienteID INT PRIMARY KEY,
    ClienteKey NVARCHAR(50) NOT NULL,
    NombreCliente NVARCHAR(255) NOT NULL,
    Email NVARCHAR(255),
    Telefono NVARCHAR(50),
    Direccion NVARCHAR(MAX),
    Ciudad NVARCHAR(100),
    CodigoPostal NVARCHAR(20),
    Pais NVARCHAR(100) DEFAULT 'Colombia',
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    FechaModificacion DATETIME,
    Activo BIT NOT NULL DEFAULT 1
);

-- Dimensión Empleado
CREATE TABLE DimEmpleado (
    EmpleadoID INT PRIMARY KEY,
    EmpleadoKey NVARCHAR(50) NOT NULL,
    NombreEmpleado NVARCHAR(255) NOT NULL,
    Puesto NVARCHAR(100) NOT NULL,
    Email NVARCHAR(255),
    Telefono NVARCHAR(50),
    FechaContratacion DATETIME,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    FechaModificacion DATETIME,
    Activo BIT NOT NULL DEFAULT 1
);

-- Dimensión Proveedor
CREATE TABLE DimProveedor (
    ProveedorID INT PRIMARY KEY,
    ProveedorKey NVARCHAR(50) NOT NULL,
    NombreProveedor NVARCHAR(255) NOT NULL,
    Contacto NVARCHAR(255),
    Telefono NVARCHAR(50),
    Direccion NVARCHAR(MAX),
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    FechaModificacion DATETIME,
    Activo BIT NOT NULL DEFAULT 1
);

-- Dimensión Transportista
CREATE TABLE DimTransportista (
    TransportistaID INT PRIMARY KEY,
    TransportistaKey NVARCHAR(50) NOT NULL,
    NombreTransportista NVARCHAR(255) NOT NULL,
    Contacto NVARCHAR(255),
    Telefono NVARCHAR(50),
    Email NVARCHAR(255),
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    FechaModificacion DATETIME,
    Activo BIT NOT NULL DEFAULT 1
);

-- Dimensión Ubicacion
CREATE TABLE DimUbicacion (
    UbicacionID INT IDENTITY(1,1) PRIMARY KEY,
    Ciudad NVARCHAR(100) NOT NULL,
    CodigoPostal NVARCHAR(20),
    Pais NVARCHAR(100) NOT NULL DEFAULT 'Colombia',
    Region NVARCHAR(100),
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    FechaModificacion DATETIME,
    Activo BIT NOT NULL DEFAULT 1
);

-- Dimensión Estado Envio
CREATE TABLE DimEstadoEnvio (
    EstadoEnvioID INT IDENTITY(1,1) PRIMARY KEY,
    NombreEstado NVARCHAR(50) NOT NULL,
    Descripcion NVARCHAR(255),
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    FechaModificacion DATETIME
);

-- =============================================
-- TABLAS DE HECHOS
-- =============================================

-- Tabla de Hechos de Ventas
CREATE TABLE FactVentas (
    VentaID BIGINT IDENTITY(1,1) PRIMARY KEY,
    TiempoID INT FOREIGN KEY REFERENCES DimTiempo(TiempoID),
    ProductoID INT FOREIGN KEY REFERENCES DimProducto(ProductoID),
    ClienteID INT FOREIGN KEY REFERENCES DimCliente(ClienteID),
    EmpleadoID INT FOREIGN KEY REFERENCES DimEmpleado(EmpleadoID),
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(18, 2) NOT NULL,
    Descuento DECIMAL(18, 2) DEFAULT 0.00,
    Total DECIMAL(18, 2) NOT NULL,
    VentaSourceID BIGINT, -- ID de la venta en la tabla fuente
    DetalleVentaSourceID BIGINT, -- ID del detalle de venta en la tabla fuente
    FechaCarga DATETIME NOT NULL DEFAULT GETDATE()
);

-- Tabla de Hechos de Inventario
CREATE TABLE FactInventario (
    InventarioID BIGINT IDENTITY(1,1) PRIMARY KEY,
    TiempoID INT FOREIGN KEY REFERENCES DimTiempo(TiempoID),
    ProductoID INT FOREIGN KEY REFERENCES DimProducto(ProductoID),
    Cantidad INT NOT NULL,
    InventarioSourceID BIGINT, -- ID del inventario en la tabla fuente
    FechaCarga DATETIME NOT NULL DEFAULT GETDATE()
);

-- Tabla de Hechos de Envíos
CREATE TABLE FactEnvios (
    EnvioID BIGINT IDENTITY(1,1) PRIMARY KEY,
    TiempoID_FechaEnvio INT FOREIGN KEY REFERENCES DimTiempo(TiempoID),
    TiempoID_FechaEstimadaEntrega INT FOREIGN KEY REFERENCES DimTiempo(TiempoID),
    TiempoID_FechaEntrega INT FOREIGN KEY REFERENCES DimTiempo(TiempoID),
    ProductoID INT FOREIGN KEY REFERENCES DimProducto(ProductoID),
    ClienteID INT FOREIGN KEY REFERENCES DimCliente(ClienteID),
    TransportistaID INT FOREIGN KEY REFERENCES DimTransportista(TransportistaID),
    UbicacionOrigenID INT FOREIGN KEY REFERENCES DimUbicacion(UbicacionID),
    UbicacionDestinoID INT FOREIGN KEY REFERENCES DimUbicacion(UbicacionID),
    EstadoEnvioID INT FOREIGN KEY REFERENCES DimEstadoEnvio(EstadoEnvioID),
    MetodoEnvio NVARCHAR(50),
    DuracionEstimada INT, -- En horas
    DuracionReal INT, -- En horas
    CostoEnvio DECIMAL(18, 2),
    OrdenEnvioSourceID BIGINT, -- ID de la orden de envío en la tabla fuente
    DetalleEnvioSourceID BIGINT, -- ID del detalle de envío en la tabla fuente
    RutaEnvioSourceID BIGINT, -- ID de la ruta de envío en la tabla fuente
    FechaCarga DATETIME NOT NULL DEFAULT GETDATE()
);

-- =============================================
-- ÍNDICES
-- =============================================

-- Índices para mejorar el rendimiento en consultas comunes
CREATE NONCLUSTERED INDEX IX_FactVentas_TiempoID ON FactVentas(TiempoID);
CREATE NONCLUSTERED INDEX IX_FactVentas_ProductoID ON FactVentas(ProductoID);
CREATE NONCLUSTERED INDEX IX_FactVentas_ClienteID ON FactVentas(ClienteID);

CREATE NONCLUSTERED INDEX IX_FactInventario_TiempoID ON FactInventario(TiempoID);
CREATE NONCLUSTERED INDEX IX_FactInventario_ProductoID ON FactInventario(ProductoID);

CREATE NONCLUSTERED INDEX IX_FactEnvios_TiempoID_FechaEnvio ON FactEnvios(TiempoID_FechaEnvio);
CREATE NONCLUSTERED INDEX IX_FactEnvios_ProductoID ON FactEnvios(ProductoID);
CREATE NONCLUSTERED INDEX IX_FactEnvios_ClienteID ON FactEnvios(ClienteID);
CREATE NONCLUSTERED INDEX IX_FactEnvios_EstadoEnvioID ON FactEnvios(EstadoEnvioID);

PRINT 'Data Warehouse creado exitosamente'
GO
