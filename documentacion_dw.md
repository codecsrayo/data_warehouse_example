# Documentación del Data Warehouse para Temu Colombia

## Introducción

Este documento describe la implementación de un Data Warehouse para Temu Colombia, un sistema de ventas y envíos. El Data Warehouse (DW) fue diseñado siguiendo un enfoque de modelado dimensional tipo estrella, permitiendo análisis eficientes de datos empresariales y soporte a decisiones.

## Arquitectura del Data Warehouse

La arquitectura implementada sigue el modelo dimensional tipo estrella, con tablas de hechos (fact tables) en el centro y tablas de dimensiones (dimension tables) a su alrededor. Esta arquitectura es ideal para consultas analíticas y reporting.

### Diagrama Conceptual

```
               ┌─────────────┐    ┌───────────┐
               │ DimTiempo   │    │DimProducto│
               └──────┬──────┘    └─────┬─────┘
                      │                 │
┌──────────┐    ┌─────┴─────────────────┴───┐    ┌────────────┐
│DimCliente│────┤        FactVentas         ├────│DimEmpleado │
└──────────┘    └─────┬─────────────────────┘    └────────────┘
                      │
               ┌──────┴──────┐
               │FactInventario│
               └──────┬───────┘
                      │
┌───────────────┐    ┌┴───────────┐    ┌──────────────────┐
│DimTransportista├───┤ FactEnvios  ├────┤DimEstadoEnvio   │
└───────────────┘    └─────┬───────┘    └──────────────────┘
                           │
                    ┌──────┴──────┐
                    │DimUbicacion │
                    └─────────────┘
```

## Paso a Paso de la Implementación

### 1. Creación de la Base de Datos y Esquema del DW

Se creó una nueva base de datos `DW_TemuColombia` para albergar el data warehouse. La estructura incluye:

- 8 tablas de dimensiones (DimTiempo, DimProducto, DimCliente, DimEmpleado, DimProveedor, DimTransportista, DimUbicacion, DimEstadoEnvio)
- 3 tablas de hechos (FactVentas, FactInventario, FactEnvios)

Cada tabla fue diseñada con sus claves primarias y claves foráneas adecuadas para mantener la integridad referencial.

**Archivo:** `01_crear_data_warehouse.sql`

### 2. Carga de Tablas de Dimensiones

Se implementó el proceso ETL para la carga inicial de datos en las tablas de dimensiones:

- **DimTiempo:** Generada sintéticamente para un período de 5 años, con atributos de jerarquía temporal
- **DimProducto, DimCliente, DimEmpleado, etc.:** Cargadas desde las tablas OLTP correspondientes en BDTemuColombia
- **DimUbicacion:** Cargada a partir de ciudades únicas en envíos y rutas

**Archivo:** `02_cargar_dimensiones.sql`

### 3. Carga de Tablas de Hechos

Una vez cargadas las dimensiones, se poblaron las tablas de hechos:

- **FactVentas:** Creada a partir de las tablas Ventas y DetalleVentas del OLTP
- **FactInventario:** Poblada desde la tabla Inventario del OLTP
- **FactEnvios:** Combinada de OrdenesEnvio, DetallesEnvio y RutasEnvio del OLTP

Durante este proceso se aseguró la concordancia entre las claves del OLTP y las dimensiones del DW.

**Archivo:** `03_cargar_tablas_hechos.sql`

### 4. Limpieza y Calidad de Datos

Se implementaron procedimientos para asegurar la calidad de los datos:

- **Estandarización de categorías:** Normalización de nombres de categorías de productos
- **Normalización de datos de clientes:** Formatos de correos electrónicos, teléfonos y ciudades
- **Corrección de anomalías numéricas:** Manejo de valores extremos en precios, cantidades e inventarios
- **Detección de duplicados:** Identificación de registros potencialmente duplicados
- **Verificación de integridad referencial:** Corrección de registros huérfanos

**Archivo:** `04_limpieza_y_calidad_datos.sql`

### 5. Cargas Incrementales

Se diseñó un sistema de carga incremental para actualizar el data warehouse con nuevos datos sin recargar todo desde cero:

- **Tabla de Control:** Para registrar la última carga y controlar el proceso de actualización
- **Procedimientos incrementales:** Ejemplos para DimProducto, FactVentas y FactInventario
- **Manejo de SCD (Slowly Changing Dimensions):** Implementación de SCD Tipo 2 para dimensiones con históricos

**Archivo:** `05_carga_incremental.sql`

### 6. Metadatos

Se creó un sistema de metadatos para documentar el data warehouse:

- **MetadatosDW:** Información sobre tablas, tipos, dependencias y granularidad
- **MetadatosColumnas:** Detalles de columnas, claves, tipos de datos y descripciones
- **Procedimientos de actualización:** Automatización para mantener los metadatos actualizados

**Archivo:** `06_metadatos.sql`

## Especificaciones Técnicas

### Tablas de Hechos

1. **FactVentas**
   - Granularidad: A nivel de línea de detalle de venta (una fila por producto en una venta)
   - Medidas principales: Cantidad, PrecioUnitario, Total
   - Dimensiones relacionadas: Tiempo, Producto, Cliente, Empleado

2. **FactInventario**
   - Granularidad: A nivel de producto y fecha
   - Medidas principales: Cantidad
   - Dimensiones relacionadas: Tiempo, Producto

3. **FactEnvios**
   - Granularidad: A nivel de envío individual
   - Medidas principales: DuracionEstimada, DuracionReal, CostoEnvio
   - Dimensiones relacionadas: Tiempo, Producto, Cliente, Transportista, Ubicaciones, EstadoEnvio

### Tablas de Dimensiones

1. **DimTiempo**
   - Jerarquías temporales: Año > Trimestre > Mes > Semana > Día
   - Atributos descriptivos: NombreMes, NombreDiaSemana, EsFestivo

2. **DimProducto**
   - Jerarquía de producto: Categoría > Producto
   - Atributos: NombreProducto, Descripcion, PrecioActual
   - SCD Tipo 2 para capturar cambios históricos en productos

3. **DimCliente**
   - Atributos: NombreCliente, Email, Telefono, Direccion, etc.
   - Jerarquía geográfica: País > Ciudad > CodigoPostal

4. **DimUbicacion**
   - Jerarquía geográfica: País > Region > Ciudad
   - Atributos: CodigoPostal

## Procesos ETL

### Extracción

- Los datos se extraen de la base de datos OLTP `BDTemuColombia`
- Se utilizan consultas SQL para seleccionar los datos relevantes
- Se implementan filtros para seleccionar solo los cambios desde la última carga

### Transformación

- Limpieza de datos (estandarización, normalización)
- Corrección de valores fuera de rango
- Generación de claves subrogadas
- Resolución de valores faltantes
- Eliminación de duplicados

### Carga

- Carga inicial para todas las tablas
- Procedimientos de carga incremental para actualizaciones
- Control de errores y transaccionalidad
- Registro de metadata y control de cargas

## Consideraciones de Calidad de Datos

1. **Integridad referencial:** Se asegura que todas las claves foráneas en las tablas de hechos correspondan a registros existentes en las tablas de dimensiones.

2. **Valores nulos:** Se implementan valores predeterminados y se manejan adecuadamente los valores nulos.

3. **Estandarización:** Se normalizan categorías, ciudades y otros campos categóricos.

4. **Duplicados:** Se detectan y manejan registros potencialmente duplicados.

5. **Valores extremos:** Se identifican y corrigen valores numéricos fuera de rangos esperados.

## Conclusiones

Este data warehouse proporciona una base sólida para el análisis de datos de Temu Colombia, facilitando reportes y análisis de ventas, inventario y envíos. La arquitectura dimensional permite consultas eficientes y análisis multidimensionales.

La implementación incluye procesos de calidad de datos y métodos de carga incremental que garantizan que los datos permanezcan precisos y actualizados con el tiempo.

## Próximos Pasos Recomendados

1. **Implementar procesos ETL automatizados:** Programar las cargas incrementales para ejecutarse automáticamente.

2. **Desarrollo de cubos OLAP:** Para análisis más avanzados y multidimensionales.

3. **Implementación de dashboards:** Desarrollo de interfaces visuales para explorar los datos.

4. **Integración con herramientas de BI:** Como Power BI, Tableau o QlikView.

5. **Extensión del modelo:** Incorporar nuevas dimensiones según evolucionen los requerimientos de negocio.
