# Changelog

Todas las novedades y cambios notables de Fireflytonic se documentan en este archivo.

## [3.0.8-beta.5] - 2026-10-15
### Rediseño y Mejoras
- **Rediseño completo de la pantalla de Cuentas**:
  - **Resumen patrimonial interactivo**: Visualización destacada en tarjeta superior de Activos Totales, Deuda/Pasivos acumulados y Patrimonio Neto calculado en tiempo real con selector de cuentas activas/inactivas.
  - **Filtrado segmentado**: Navegación rápida por categorías de cuenta mediante SegmentedButton (Todas, Activos, Pasivos, Otras) y opción de mostrar u ocultar cuentas inactivas.
  - **Buscador en tiempo real**: Filtro instantáneo de cuentas por nombre, entidad bancaria, número de cuenta, notas o IBAN.
  - **Identidad visual con BankLogoBadge**: Detección inteligente de bancos (BBVA, Santander, CaixaBank, ING, Openbank, Revolut, Sabadell, Bankinter, Wise, N26, etc.) con colores corporativos e iconos de tarjeta o billetera.
  - **Tarjetas de cuenta estilo Fintonic**: Saldo en cifras tabulares y colores semánticos (verde/coral), rol de cuenta, IBAN abreviado, TAE para pasivos y menú rápido de acciones (ver movimientos, editar o eliminar).
  - **Nuevo diálogo de creación y edición**: Formulario modal completo para añadir o modificar cuentas con selección de tipo, rol, IBAN, saldo inicial, intereses y notas.
  - **Interfaz despejada**: Se elimina la barra de pestañas saturada del AppBar, integrando buscador y alta en la barra superior y botón flotante (FAB).

## [3.0.8-beta.4] - 2026-10-15
### Mejoras
- **Visibilidad de importes en menú lateral**: Se traslada el botón del ojo para ocultar o mostrar los importes de la barra superior al menú lateral (cabecera del drawer junto al logotipo de Fireflytonic y panel lateral en pantallas medianas/grandes), despejando la barra superior.

## [3.0.8-beta.3] - 2026-10-14
### Novedades y Mejoras
- **Acción para quitar filtros**: En la pantalla de búsqueda y filtros, se añade la acción rápida "Quitar filtros" (con acceso directo en la barra superior, píldora destacada en la fila de filtros y botón en la vista vacía) para restablecer todos los criterios de búsqueda con un solo toque.
- **Exportación de movimientos a CSV**: Nueva pantalla y servicio para exportar movimientos filtrados por rango de fechas y cuentas/tarjetas a archivo CSV con formato español y codificación UTF-8 con BOM.

## [3.0.8-beta.2] - 2026-10-14
### Mejoras
- **Logo de Fireflytonic en menú lateral**: Se sustituye el icono genérico de la copa por el logotipo oficial de Fireflytonic junto al nombre de la app en la cabecera del menú lateral.

## [3.0.8-beta.1] - 2026-10-14
### Mejoras
- **Importación bancaria en menú lateral**: Se mueve el acceso a la importación bancaria desde la pantalla de Ajustes directamente al menú lateral principal (drawer/rail) para un acceso más rápido y visible.

## [3.0.7] - 2026-10-14
### Novedades y Mejoras
- **Lanzamiento oficial en nuevo repositorio**: Configuración del pipeline de release y firma con claves de producción en el repositorio público Fireflytonic.
- **Sincronización de versiones y URLs**: Alineación de enlaces de documentación, comprobación de actualizaciones y constantes de versión en la app.

## [3.0.6] - 2026-10-13
### Novedades y Mejoras
- **Importación bancaria desde la app**: Nueva pantalla en Ajustes para ejecutar el importador de Firefly III por fuente (BBVA, Trade Republic), con configuración de intervalo mínimo, límite de consultas, pausa tras error 429 y conciliación de transferencias.
- **Registro de importaciones**: Se muestra la última importación de cada fuente y un historial (manual y programado) con los movimientos importados en cada ejecución.
- **Protección de límites del banco**: El servicio bloquea ejecuciones repetidas (un solo import a la vez, intervalo mínimo, presupuesto de consultas en 24 h con reserva para el cron y pausa tras 429) para no agotar el límite de Enable Banking.
- **Optimizaciones de CI y sanitización**: Parametrización de URLs de actualización, sanitización de configuraciones y mejoras en el pipeline de release.

## [3.0.5] - 2026-10-11
### Novedades y Mejoras
- **Modo de privacidad (Ocultar importes)**: Nuevo botón de visibilidad (icono del ojo) en la barra superior (a la derecha en la navegación principal y pantallas de detalle) para ocultar o mostrar los importes financieros de toda la aplicación, enmascarándolos (`••••`) para mayor privacidad en lugares públicos.
- **Ordenación optimizada en pantalla de presupuestos**: Las categorías de presupuestos ahora se muestran ordenadas de mayor a menor presupuesto asignado (y secundariamente por gasto consumido descendente).
- **Soporte de canal Beta configurable y flavors**: Convivencia de aplicaciones estable y beta en el mismo dispositivo y selector de canal de actualizaciones en ajustes.
- **Optimizaciones de CI y runner self-hosted**: Gestión de cuotas, concurrencia y despliegue automatizado de artefactos.

## [3.0.5-beta.4] - 2026-10-13
### Novedades
- **Importación bancaria desde la app**: Nueva pantalla en Ajustes para ejecutar el importador de Firefly III por fuente (BBVA, Trade Republic), con configuración de intervalo mínimo, límite de consultas, pausa tras error 429 y conciliación de transferencias.
- **Registro de importaciones**: Se muestra la última importación de cada fuente y un historial (manual y programado) con los movimientos importados en cada ejecución.
- **Protección de límites del banco**: El servicio bloquea ejecuciones repetidas (un solo import a la vez, intervalo mínimo, presupuesto de consultas en 24 h con reserva para el cron y pausa tras 429) para no agotar el límite de Enable Banking.

## [3.0.5-beta.3] - 2026-10-11
### Mejoras
- **Botón de visibilidad/privacidad en la barra superior**: Se sitúa el icono del ojo para ocultar o mostrar importes siempre a la derecha del todo en la barra superior de la navegación principal y en pantallas de detalle.
- **Ordenación en pantalla de presupuestos**: Las categorías de presupuestos ahora se ordenan de mayor a menor presupuesto asignado (y secundariamente por gasto consumido).

## [3.0.5-beta.2] - 2026-10-09
### Novedades
- **Modo de privacidad (Ocultar importes)**: Nuevo botón de visibilidad en la barra superior para ocultar o mostrar los importes financieros de toda la aplicación, reemplazándolos por una máscara discreta (`••••`) para mayor privacidad en lugares públicos.

## [3.0.5-beta.1] - 2026-10-09
### Mejoras
- **Ordenación en pantalla de presupuestos**: Las categorías de presupuestos ahora se muestran ordenadas por uso (gasto consumido descendente) y presupuesto asignado descendente.

## [3.0.4] - 2026-10-09
### Correcciones
- **Deserialización segura de IDs e importes en modelos de Firefly III**: Soporte para IDs, identificadores de grupo (`object_group_id`), monedas e importes devueltos como tipos numéricos o enteros por la API de Firefly III, evitando errores de tipado en presupuestos, límites, cuentas, facturas y huchas.

## [3.0.3] - 2026-10-08
### Novedades
- **Análisis mensual con presupuesto**: En la vista de análisis mensual, si el mes seleccionado cuenta con presupuesto asignado, la comparativa principal y barra de progreso se calculan como Gastos vs Presupuesto, mostrando también el porcentaje de ingresos gastados y detalle de restante/ahorro neto.
- **Filtro de presupuesto en movimientos y búsqueda**: Integración completa del filtro de presupuesto en la pantalla de búsqueda con selector modal (`BudgetFilterSheet`), píldora activa, chip de borrado en la cabecera de saldo y visualización clara en el selector de filtros.

### Correcciones
- **Soporte de gastos de presupuesto históricos (meses anteriores)**: En la vista de presupuestos, ahora se obtienen los importes consumidos directamente de los presupuestos (`spent`) incluso para meses pasados donde no exista un límite explícito creado en Firefly III, reflejando de forma inmediata la asignación de reglas retroactivas.

## [3.0.2] - 2026-10-08
### Novedades
- **Asignación retroactiva de reglas sin recalcular**: Añadida acción directa en la pantalla de Presupuestos (en la barra superior con icono y en la cabecera de la lista de presupuestos con el botón "Aplicar reglas") para ejecutar retroactivamente las reglas de presupuestos de Firefly III sobre todos los movimientos del mes en curso con un solo toque.

## [3.0.1] - 2026-10-08
### Correcciones
- **Asignación retroactiva de presupuestos**: Corrección en el cliente HTTP de Firefly III inyectando la cabecera `Content-Type: application/json` en peticiones `POST`/`PUT`/`PATCH` sin cuerpo (evitando el error HTTP 415 devuelto por la API al disparar reglas sobre movimientos existentes).
- **Paginación de reglas y presupuestos**: Consulta completa de todas las páginas de reglas y presupuestos en el generador automático para no duplicar ni omitir reglas existentes.

## [3.0.0] - 2026-10-08
### Novedades
- **Módulo completo de Presupuestos**: Nueva pantalla accesible desde la barra de navegación inferior (estilo Fintonic) para gestionar presupuestos mensuales.
  - Tarjeta de resumen global del mes: gasto total vs presupuestado, saldo restante, porcentaje de consumo con barra de progreso y ritmo diario recomendado (~€/día).
  - Navegación mensual interactiva con selector de fechas y botón rápido para volver al mes actual ("Hoy").
  - Lista de presupuestos por categoría con iconos temáticos, progreso visual y estado (restante o excedido).
  - Opciones de presupuesto: consulta directa de movimientos asignados, edición rápida de importe mensual y borrado en Firefly III.
  - **Generador inteligente desde histórico**: Asistente que analiza los gastos reales de los últimos 3 o 6 meses, calcula medias por categoría, propone límites editables y genera presupuestos automáticamente en Firefly III.
  - **Automatización con reglas de Firefly III**: Opción para crear reglas automáticas que asocien futuros movimientos a sus presupuestos y vinculación retroactiva sobre los gastos del mes en curso.

## [2.3.6] - 2026-10-08
### Novedades
- **Búsqueda y filtros estilo Fintonic**: Rediseño de la interfaz de búsqueda y filtros accesible desde el botón superior de movimientos.
  - Pantalla dedicada con barra de búsqueda y movimientos en tiempo real agrupados por fechas.
  - Píldoras de filtro rápido para fechas (último mes, 3 meses, año y personalizado).
  - Modal de categorías con pestañas (Gastos, Ingresos, No computable), grupos temáticos y switches.
  - Modal de cuentas y tarjetas con badges bancarios y selección múltiple.

## [2.3.5] - 2026-10-08
### Mejoras
- **Filtros de análisis**: Botones de gastos e ingresos centrados horizontalmente y con mayor separación entre ellos.

## [2.3.4] - 2026-10-07
### Mejoras
- **Filtros rápidos de gastos e ingresos en análisis**: Añadidos filtros rápidos horizontales entre el Neto y el gráfico para alternar entre el análisis por categorías de gastos y el análisis por categorías de ingresos.
- **Detalle de categoría para ingresos**: Soporte completo para visualizar el histórico de barras y movimientos de categorías de ingresos al pulsar sobre ellas.
### Mejoras
- **Navegación por páginas en análisis**: Las flechas laterales (< y >) ahora pasan de página completa (bloque de 6 meses o del periodo seleccionado) en lugar de desplazar un único mes.

## [2.3.2] - 2026-10-07
### Solución de errores y mejoras
- **Navegación en gráficos de barras**: Solucionadas las flechas laterales (< y >) para avanzar y retroceder meses y periodos de forma fluida y continua.
- **Changelog in-app**: Añadido soporte para mostrar el registro de novedades directamente en el diálogo de actualización de la app.

## [2.3.1] - 2026-10-06
- Volver a 6 meses en vista de análisis y detalle de categoría.

## [2.3.0] - 2026-10-06
- Mostrar 6 meses en análisis por defecto.

## [2.2.0] - 2026-10-06
- Mostrar 12 meses en análisis y compactar barras.

## [2.1.0] - 2026-10-06
- Enviar parámetro `types` en endpoints de transacciones para compatibilidad con Firefly III.

## [2.0.0] - 2026-10-05
- Nuevos logos e iconos adaptativos estilo Fintonic.
