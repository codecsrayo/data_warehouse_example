-- SCRIPT MAESTRO PARA EJECUTAR TODA LA IMPLEMENTACIÓN DEL DATA WAREHOUSE
-- Este script ejecuta todos los scripts en orden secuencial

PRINT '==================================================================='
PRINT 'IMPLEMENTACIÓN DEL DATA WAREHOUSE TEMU COLOMBIA'
PRINT 'Fecha de ejecución: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '==================================================================='
PRINT ''

PRINT 'PASO 1: Crear estructura del Data Warehouse'
PRINT '-------------------------------------------------------------------'
:r 01_crear_data_warehouse.sql
PRINT 'Estructura del Data Warehouse creada exitosamente'
PRINT ''

PRINT 'PASO 2: Cargar tablas de dimensiones'
PRINT '-------------------------------------------------------------------'
:r 02_cargar_dimensiones.sql
PRINT 'Tablas de dimensiones cargadas exitosamente'
PRINT ''

PRINT 'PASO 3: Cargar tablas de hechos'
PRINT '-------------------------------------------------------------------'
:r 03_cargar_tablas_hechos.sql
PRINT 'Tablas de hechos cargadas exitosamente'
PRINT ''

PRINT 'PASO 4: Ejecutar limpieza y verificación de calidad de datos'
PRINT '-------------------------------------------------------------------'
:r 04_limpieza_y_calidad_datos.sql
PRINT 'Limpieza y verificación de calidad de datos completada'
PRINT ''

PRINT 'PASO 5: Configurar carga incremental'
PRINT '-------------------------------------------------------------------'
:r 05_carga_incremental.sql
PRINT 'Configuración de carga incremental completada'
PRINT ''

PRINT 'PASO 6: Generar metadatos'
PRINT '-------------------------------------------------------------------'
:r 06_metadatos.sql
PRINT 'Generación de metadatos completada'
PRINT ''

PRINT '==================================================================='
PRINT 'PASO 7: Validar datos del Data Warehouse'
PRINT '-------------------------------------------------------------------'
:r 07_validacion_datos.sql
PRINT 'Validación de datos completada'
PRINT ''

PRINT '==================================================================='
PRINT 'IMPLEMENTACIÓN DEL DATA WAREHOUSE COMPLETADA EXITOSAMENTE'
PRINT 'Fecha y hora de finalización: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '==================================================================='

-- Para ver la documentación completa, consulte el archivo documentacion_dw.md
-- Para obtener más información sobre el proyecto, consulte el archivo README.md
