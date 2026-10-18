# Changelog

Todas las novedades notables de Fireflytonic se documentan en este archivo.

## [3.2.1-beta.3] - 2026-10-18

### Fixed
- **Pantalla gris en Categorías (`lib/pages/categories.dart`, `lib/stock.dart`, `lib/extensions.dart`)**:
  - Al cargar categorías desde la caché de disco, los objetos se deserializaban como `CategoryProperties` en lugar de `CategoryWithSum`, provocando un `TypeError` y una pantalla gris.
  - `CatStock` reconstruye ahora `CategoryWithSum` con `sumSpent` y `sumEarned` al leer de `PersistentSourceOfTruth`.
  - Añadida extensión segura `CategoryPropertiesSumExt` en `extensions.dart` con getters `sumSpent` y `sumEarned` que funcionan tanto para `CategoryWithSum` como para `CategoryProperties`.
  - Refactorizado `CategoriesPage` para usar carga determinista mediante `_loadData()`, eliminando el `FutureBuilder` recreado en `build()` y todos los casts inseguros a `CategoryWithSum`.

### Changed
- **Acciones duplicadas en Presupuestos (`lib/pages/home/budgets.dart`)**:
  - Eliminados los botones duplicados `auto_awesome` y `rule_folder` del `AppBar`; las acciones de generar presupuestos y aplicar reglas ya están presentes como `TextButton` en la cabecera "MIS PRESUPUESTOS". Solo permanece el botón de añadir presupuesto en el `AppBar`.

---

## [3.2.1-beta.2] - 2026-10-18

### Changed
- **Eje vertical adaptativo en gráficos de Evolución (`lib/pages/home/evolution.dart`)**:
  - Los gráficos de **Patrimonio Neto** y **Saldo Agregado** ajustan ahora dinámicamente los límites del eje Y, centrándolos en la media de los datos en lugar de forzar el inicio en 0.
  - La línea de la serie se sitúa aproximadamente a mitad del gráfico, mejorando la legibilidad cuando los importes son altos y las variaciones relativas pequeñas (por ejemplo, patrimonios de ~50.000 € que oscilan entre 49.000 € y 51.000 €).

---

## [3.2.1-beta.1] - 2026-10-18

### Added
- **Detalle temporal en gráficos de Evolución (`lib/pages/home/evolution.dart`)**:
  - Al pulsar sobre los gráficos de evolución de Patrimonio Neto y Saldo, la línea vertical (trackball) muestra ahora la fecha además del importe (`d MMM` en rango mensual, `d MMM yyyy` en periodos superiores), formateado con la divisa y respetando el modo de privacidad (`hideAmounts`).

---

## [3.2.0] - 2026-10-17

### Novedades y Análisis Financiero
- **Nueva pantalla de Evolución y Análisis (`lib/pages/home/evolution.dart`)**:
  - **4 modos de visualización financiera**:
    - **Patrimonio Neto**: Curva evolutiva del patrimonio neto (activos descontando pasivos reales de forma continua) con granularidad adaptativa y gráficos suaves.
    - **Saldo Agregado**: Saldo total y acumulado real de las cuentas bancarias a lo largo del tiempo.
    - **Flujo de Efectivo**: Comparativa visual mensual de ingresos frente a gastos con tasa de ahorro calculada.
    - **Distribución por Categorías**: Gráfico interactivo estilo dona con selector bidireccional y desglose detallado de gastos.
  - **Gráficos interactivos de alta fluidez**:
    - Curvas `SplineAreaSeries` con interpolación suave (`SplineType.monotonic`) y degradados elegantes.
    - Gráfico circular (`SfCircularChart`) con etiquetas exteriores anticolisión, líneas conectoras y leyenda tipo chips compacta (`Wrap`) que evita scroll innecesario.
    - Indicador central táctil con importe y porcentaje al seleccionar sectores del gráfico.
    - Eliminado el *stuttering* de dibujado y transiciones de frames optimizadas.
  - **Selector temporal estilo Fintonic**:
    - Rango temporal rápido (1M, 3M, 6M, 1A, Todo) y selector de fechas personalizado con calendario modal.
  - **Filtros avanzados**:
    - Filtrado modal por cuentas de activo activas y por categorías específicas.
  - **Tarjetas de KPIs y desglose**:
    - Resumen superior con variación absoluta y porcentual del periodo, tasa de ahorro y ranking inferior de gastos con barras de progreso `FtProgressBar`.
    - Respeto total al modo de ocultar importes (`SettingsProvider.hideAmounts`) y compatibilidad plena con temas claro y oscuro de alto contraste.

### Navegación y Usabilidad
- **Reorganización de la barra inferior (`lib/pages/home.dart`)**:
  - Incorporada la nueva pestaña de **Evolución** (`Icons.insights_outlined` / `Icons.insights`) directamente en la navegación principal.
- **Acceso a Huchas en menú lateral (`lib/pages/piggybanks.dart`)**:
  - Trasladado el acceso a metas de ahorro y huchas al menú lateral principal (drawer) para una interfaz más despejada y coherente.

### Configuración y Experiencia de Usuario
- **Estructuración temática de Ajustes (`lib/pages/settings.dart`)**:
  - Reorganizada la pantalla de Configuración en bloques limpios: *Apariencia y gráficos*, *Servidor y seguridad*, *Notificaciones* y *Acerca de*.
  - Eliminado el enlace redundante a FAQ para simplificar la navegación.
- **Unificación de periodo por defecto para gráficos**:
  - La opción de periodo por defecto de gráficos sincroniza tanto el gráfico de patrimonio de inicio como el rango inicial de Evolución.
- **Centro de Actualizaciones y gestión de versiones (`lib/updater.dart`)**:
  - Nuevo diálogo modal de Actualizaciones que permite alternar cómodamente entre el canal Estable y Beta y verificar actualizaciones.
  - Preservación del contexto raíz de navegación al descargar e instalar APKs desde los ajustes.
- **Claridad de textos y limpieza visual**:
  - Simplificada la opción de bloqueo de pantalla a «Requerir autenticación».
  - Eliminado el subtítulo explicativo redundante en la opción «Usar la zona horaria del servidor».

---

## [3.2.0-beta.9] - 2026-10-17

### Changed
- **Ajustes de interfaz y textos (`lib/pages/settings.dart`, `lib/l10n/app_es.arb`)**:
  - Eliminado subtítulo redundante en «Usar la zona horaria del servidor» para una interfaz más limpia y compacta.
  - Simplificada la descripción de bloqueo de pantalla a «Requerir autenticación» (eliminada la coletilla «al iniciar la aplicación»).

---

## [3.2.0-beta.8] - 2026-10-17

### Fixed
- **Botón de descarga de actualización (`lib/updater.dart`, `lib/pages/settings.dart`)**:
  - Resuelto el fallo al pulsar «Actualizar ahora» tras buscar versión desde el diálogo de ajustes: ahora se preserva el `BuildContext` raíz de la aplicación (`navigatorKey.currentContext`) para abrir el diálogo de descarga de APK sin cancelarse por el cierre del diálogo de ajustes.
- **Ajuste visual en Selector de Modo de Evolución (`lib/pages/home/evolution.dart`)**:
  - Corrección de truncamiento en textos «Patrimonio» y «Categorías»: aplicado padding compacto, tamaño de fuente optimizado a 11sp y desactivado el corte elíptico en pantallas estrechas.
- **Legibilidad en centro del gráfico circular (`lib/pages/home/evolution.dart`)**:
  - El texto de conteo de categorías («N categorías») ahora utiliza `onSurfaceVariant` con `FontWeight.w600` en modo oscuro, garantizando total nitidez y contraste.
- **Suavidad de curvas y stuttering en gráficos (`lib/pages/home/evolution.dart`)**:
  - Gráficos de Patrimonio Neto y Saldo restaurados a curvas redondeadas y suaves mediante `SplineAreaSeries` con interpolación `SplineType.monotonic` (sin vértices puntiagudos artificiales).
  - Eliminado el *stuttering* y caídas de frames al navegar y seleccionar filtros configurando `animationDuration: 0` en el motor de renderizado de Syncfusion.

---

## [3.2.0-beta.7] - 2026-10-17

### Fixed
- **Cálculo de Patrimonio Neto (`lib/pages/home/evolution.dart`)**:
  - Corrección en el cálculo del patrimonio neto donde los pasivos (*liabilities*) se sumaban en vez de restarse de los activos.
  - Tratamiento del valor absoluto en balances de pasivos para asegurar deducción exacta frente al activo.
- **Contraste de etiquetas y porcentajes en modo oscuro (`lib/pages/home/evolution.dart`)**:
  - Uso de `onSurfaceVariant` con peso `FontWeight.w600` en chips y desglose para asegurar alta legibilidad sobre fondos oscuros.
  - Data labels exteriores con color tipográfico adaptable de alto contraste (`onSurface`).

### Changed
- **Optimización de carga y renderizado (`lib/pages/home/evolution.dart`)**:
  - Paginación secuencial eliminada en `_fetchAccountsMap`: ahora descarga en paralelo `assetAccount` y `liabilities` con límite 100.
  - Sustitución de `SplineAreaSeries` por `AreaSeries` y desactivación de animación de re-renderizado en `explode` para eliminar el *stuttering* de dibujado.

---

## [3.2.0-beta.6] - 2026-10-17

### Added
- **Gráfico circular interactivo y leyenda optimizada en Evolución (`lib/pages/home/evolution.dart`)**:
  - Nueva leyenda responsiva tipo chips con `Wrap` que elimina el scroll incómodo sobre el gráfico, mostrando Top 5 + «Otros» de forma compacta.
  - Etiquetas de datos exteriores legibles con líneas conectoras suaves y resolución anticolisión (`shift`).
  - Interactividad y selección bidireccional entre sectores, leyenda chips, anotación central con detalle del importe/porcentaje y el ranking inferior de gastos.
- **Optimización de rendimiento y aceleración de carga (`lib/pages/home/evolution.dart`)**:
  - Paralelización con `Future.wait` de las peticiones mensuales a la API en Flujo y Saldo, reduciendo sustancialmente los tiempos de espera en periodos amplios.
  - Caché de cuentas e inicialización diferida (*lazy loading*) de filtros.

---

## [3.2.0-beta.5] - 2026-10-17

### Added
- **Unificación de periodo por defecto para gráficos (`lib/pages/settings.dart`, `lib/pages/home/evolution.dart`)**:
  - La opción de configuración «Periodo por defecto de los gráficos» ahora aplica tanto a los gráficos de patrimonio de la pantalla principal como al rango temporal inicial de la pantalla de Evolución.
  - Sincronización reactiva del periodo en Evolución cuando cambia en los ajustes.
  - Agrupación compacta de las opciones de actualización en un diálogo modal (`Actualizaciones`) para cambiar de canal (Estable/Beta) y buscar nuevas versiones.
  - Reorganización de la pantalla de Configuración en secciones temáticas (*Apariencia y gráficos*, *Servidor y seguridad*, *Notificaciones*, *Acerca de*).

### Removed
- **FAQ en Configuración**:
  - Eliminado el acceso directo a FAQ de la pantalla de ajustes para simplificar y limpiar la interfaz.

---

## [3.2.0-beta.4] - 2026-10-17

### Fixed
- **Filtro de cuentas en desglose de Evolución (`lib/pages/home/evolution.dart`)**:
  - En el desglose por cuentas de Saldo y Patrimonio únicamente se listan las cuentas activas o con movimientos dentro del periodo analizado, excluyendo cuentas inactivas sin variación de saldo.
  - El selector modal de filtrado por cuentas ahora muestra exclusivamente cuentas activas.

---

## [3.2.0-beta.3] - 2026-10-17

### Fixed
- **Cálculo y gráfico de Saldo en pantalla de Evolución (`lib/pages/home/evolution.dart`)**:
  - Corrección en `_fetchBalance()` eliminando el descarte indebido por `ds.type != 'asset'` (la API de Firefly III devuelve `type: "line"` para las series temporales del endpoint `/chart/account/overview`), permitiendo renderizar correctamente la serie temporal.
  - Clasificación y mapeo robusto de pasivos en `_fetchNetWorth()` mediante consulta de cuentas de pasivo registradas.

---

## [3.2.0-beta.2] - 2026-10-17

### Fixed
- **Cálculo de Saldo Agregado y desglose en Evolución (`lib/pages/home/evolution.dart`)**:
  - Uso del endpoint `/chart/account/overview` con filtro de cuentas de activo para calcular el saldo acumulado real y continuo en lugar del flujo diario (`earned`/`spent`).
  - Desglose inferior con el nombre real de cada cuenta bancaria/activo y su saldo correspondiente.
  - Ajuste de tamaño y desbordamiento en el selector de modos para evitar el salto de línea en "Categorías".

---

## [3.2.0-beta.1] - 2026-10-17

### Added
- **Nueva pantalla de Evolución y Análisis (`lib/pages/home/evolution.dart`)**:
  - 4 modos de análisis interactivo: Patrimonio Neto, Saldo Agregado, Flujo de Efectivo (Ingresos vs Gastos) y Distribución por Categorías.
  - Gráficos interactivos con Syncfusion (`SfCartesianChart` con curvas suaves `SplineAreaSeries` y `TrackballBehavior`, barras de flujo mensual y gráfico dona `SfCircularChart` para categorías).
  - Selector de periodo temporal estilo Fintonic: 1M, 3M, 6M, 1A, Todo y selector de rango de fechas personalizado con `showDateRangePicker`.
  - Filtros avanzados por cuentas de activo y categorías específicas mediante hoja modal (`FilterBottomSheet`).
  - Tarjetas de KPIs con variación absoluta y porcentual, desglose de activos vs pasivos, tasa de ahorro y ranking de gastos con `FtProgressBar`.
  - Respeto total al modo de ocultar saldos (`SettingsProvider.hideAmounts`) y temas claro/oscuro.
- **Acceso a Huchas desde el menú lateral (`lib/pages/piggybanks.dart`)**:
  - Nueva entrada en el menú lateral para acceder a la gestión y metas de ahorro.

### Changed
- **Reorganización de la navegación inferior (`lib/pages/home.dart`)**:
  - Se sustituye el acceso inferior de Huchas por la nueva pestaña de **Evolución** (`Icons.insights_outlined` / `Icons.insights`).

---

## [3.1.0] - 2026-10-17
### Novedades y Usabilidad
- **Periodo del gráfico de patrimonio configurable (sparkline)**:
  - Selector de rango temporal (1M, 3M, 6M, 1A, Todo) configurable en la tarjeta de patrimonio de inicio y en Ajustes de la aplicación.
  - Por defecto fijado en 1 año con granularidad adaptativa según el periodo seleccionado y visualización suave en degradado.
- **Navegación interactiva desde los chips de ingresos y gastos**:
  - Al pulsar sobre "Gastos" o "Ingresos" en la tarjeta superior, la aplicación navega automáticamente a la pestaña de Movimientos filtrando por el mes actual y por el tipo correspondiente (Gastos o Depósitos).

### Rediseño y Experiencia de Usuario
- **Rediseño completo de la pantalla de Cuentas**:
  - **Resumen patrimonial interactivo**: Visualización destacada en tarjeta superior de Activos Totales, Deuda/Pasivos acumulados y Patrimonio Neto en tiempo real con selector de cuentas activas/inactivas.
  - **Filtrado segmentado**: Navegación rápida por categorías de cuenta mediante SegmentedButton (Todas, Activos, Pasivos, Otras) y opción de mostrar u ocultar cuentas inactivas.
  - **Buscador en tiempo real**: Filtro instantáneo de cuentas por nombre, entidad bancaria, número de cuenta, notas o IBAN.
  - **Identidad visual con BankLogoBadge**: Detección inteligente de bancos (BBVA, Santander, CaixaBank, ING, Openbank, Revolut, Sabadell, Bankinter, Wise, N26, etc.) con colores corporativos e iconos de tarjeta o billetera.
  - **Tarjetas de cuenta estilo Fintonic**: Saldo en cifras tabulares y colores semánticos (verde/coral), rol de cuenta, IBAN abreviado, TAE para pasivos y menú rápido de acciones (ver movimientos, editar o eliminar).
  - **Nuevo diálogo de creación y edición**: Formulario modal completo para añadir o modificar cuentas con selección de tipo, rol, IBAN, saldo inicial, intereses y notas.
  - **Interfaz despejada**: Se elimina la barra de pestañas saturada del AppBar, integrando buscador y alta en la barra superior y botón flotante (FAB).
- **Soporte y rediseño completo de Movimientos Divididos (Split Transactions)**:
  - **Lista de movimientos y búsqueda**: Indicador visual mediante badge `call_split` en transacciones divididas. Cálculo agregado del importe total y desglose dinámico de múltiples categorías en lugar de mostrar únicamente la primera parte.
  - **Detalle de movimiento**: Desglose estructurado por tarjetas para cada sub-movimiento (con importe, descripción individual, notas, etiquetas e icono/selector de categoría interactivo) y cálculo de importe acumulado.
  - **Recategorización individual por split**: Capacidad de cambiar la categoría de una sola parte del movimiento dividido sin sobreescribir las demás.
  - **Icono de categoría unificado**: Si todas las divisiones comparten la misma categoría, se muestra el icono y color específicos de dicha categoría en lugar del icono genérico.
  - **Creación y edición de splits**: Acción "Dividir" funcional desde el detalle y la edición simple con soporte directo para añadir partes y conservar descripciones personalizadas.

### Seguridad y Privacidad
- **Desbloqueo biométrico y facial directo**:
  - Reconocimiento facial sin requerir pulsar confirmación en pantalla (`sensitiveTransaction: false`).
  - Soporte de PIN o patrón del dispositivo como respaldo en caso de fallo biométrico (`biometricOnly: false`).
  - Localización al español de los diálogos y mensajes de autenticación biométrica en Android.
- **Pantalla de bloqueo con fondo difuminado (Blur / Frosted Glass)**:
  - Superposición con desenfoque gaussiano (`BackdropFilter`) sobre la interfaz activa mientras la sesión no esté autenticada, protegiendo los datos financieros en pantalla.

## [3.0.8] - 2026-10-15
### Novedades y Mejoras
- **Exportación de movimientos a CSV**: Nueva pantalla y servicio para exportar movimientos filtrados por rango de fechas y cuentas/tarjetas a archivo CSV con formato español y codificación UTF-8 con BOM.
- **Acción para quitar filtros**: En la pantalla de búsqueda y filtros, se añade la acción rápida "Quitar filtros" (con acceso directo en la barra superior, píldora destacada en la fila de filtros y botón en la vista vacía) para restablecer todos los criterios de búsqueda con un solo toque.
- **Visibilidad de importes en menú lateral**: Se traslada el botón del ojo para ocultar o mostrar los importes de la barra superior al menú lateral (cabecera del drawer junto al logotipo de Fireflytonic y panel lateral en pantallas medianas/grandes), despejando la barra superior.
- **Importación bancaria en menú lateral**: Se mueve el acceso a la importación bancaria desde la pantalla de Ajustes directamente al menú lateral principal (drawer/rail) para un acceso más rápido y visible.
- **Logo de Fireflytonic en menú lateral**: Se sustituye el icono genérico de la copa por el logotipo oficial de Fireflytonic junto al nombre de la app en la cabecera del menú lateral.

## [3.0.8-beta.10] - 2026-10-17
### Novedades y Usabilidad
- **Periodo del gráfico de patrimonio configurable**:
  - Selector de rango temporal configurable directamente desde la tarjeta de patrimonio (1M, 3M, 6M, 1A, Todo) y en Ajustes de la aplicación.
  - Por defecto fijado en 1 año con granularidad adaptativa según el periodo seleccionado.
- **Navegación interactiva desde los chips de ingresos y gastos**:
  - Al pulsar sobre "Gastos" o "Ingresos" en la tarjeta superior, la aplicación navega automáticamente a la pestaña de Movimientos filtrando por el mes actual y por el tipo correspondiente (Gastos o Depósitos).

## [3.0.8-beta.9] - 2026-10-17
### Interfaz y Visualización
- **Gráfica de evolución del patrimonio en pantalla de inicio**:
  - En la tarjeta superior de "Patrimonio total", se dibuja una gráfica de fondo (*sparkline* curva con degradado translúcido) mostrando la evolución diaria del patrimonio durante los últimos 30 días.
  - Obtención asíncrona optimizada concurrente junto al balance mensual y soporte en caché para carga instantánea.

## [3.0.8-beta.8] - 2026-10-17
### Mejoras y Correcciones
- **Icono de categoría en movimientos divididos (splits)**:
  - En la lista de transacciones y búsquedas, si todas las divisiones de un movimiento pertenecen a la misma categoría, se muestra el icono y color específicos de dicha categoría en lugar del icono genérico.
- **Desbloqueo biométrico y facial directo**:
  - Reconocimiento facial sin requerir pulsar confirmación en pantalla (`sensitiveTransaction: false`).
  - Soporte de PIN o patrón del dispositivo como respaldo en caso de fallo biométrico (`biometricOnly: false`).
  - Localización al español de los diálogos y mensajes de autenticación biométrica en Android.
- **Pantalla de bloqueo con fondo difuminado (Blur / Frosted Glass)**:
  - Superposición con desenfoque gaussiano (`BackdropFilter`) sobre la interfaz activa mientras la sesión no esté autenticada, protegiendo los datos financieros en pantalla.

## [3.0.8-beta.7] - 2026-10-17
### Seguridad y Mejoras
- **Desbloqueo biométrico y facial directo**:
  - Reconocimiento facial sin requerir pulsar confirmación en pantalla (`sensitiveTransaction: false`).
  - Soporte de PIN o patrón del dispositivo como respaldo en caso de fallo biométrico (`biometricOnly: false`).
  - Localización al español de los diálogos y mensajes de autenticación biométrica en Android.
- **Pantalla de bloqueo con fondo difuminado (Blur / Frosted Glass)**:
  - Superposición con desenfoque gaussiano (`BackdropFilter`) sobre la interfaz activa mientras la sesión no esté autenticada, protegiendo los datos financieros en pantalla.

## [3.0.8-beta.6] - 2026-10-16
### Rediseño y Mejoras
- **Soporte y rediseño completo de Movimientos Divididos (Split Transactions)**:
  - **Lista de movimientos y búsqueda**: Indicador visual mediante badge `call_split` en transacciones divididas. Cálculo agregado del importe total y desglose dinámico de múltiples categorías en lugar de mostrar únicamente la primera parte.
  - **Detalle de movimiento**: Desglose estructurado por tarjetas para cada sub-movimiento (con importe, descripción individual, notas, etiquetas e icono/selector de categoría interactivo) y cálculo de importe acumulado.
  - **Recategorización individual por split**: Capacidad de cambiar la categoría de una sola parte del movimiento dividido sin sobreescribir las demás.
  - **Creación y edición de splits**: Acción "Dividir" reparada y funcional desde el detalle y la edición simple. Formulario de edición con soporte directo para añadir partes y conservar descripciones personalizadas por split compatibles con la validación de Firefly III.

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
