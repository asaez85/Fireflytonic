# Fireflytonic

Cliente móvil **no oficial** para [Firefly III](https://github.com/firefly-iii/firefly-iii),
el gestor de finanzas personales libre y de código abierto.

> [!IMPORTANT]
> **Proyecto personal sin soporte**
> 
> Fireflytonic es un proyecto de desarrollo personal creado y mantenido para uso propio. **No cuenta con ningún tipo de soporte oficial, garantía ni compromiso de mantenimiento o resolución de incidencias.**
> Si decides utilizar esta aplicación o compilarla por tu cuenta, lo haces bajo tu propia responsabilidad.

Este proyecto parte de [**waterfly-iii**](https://github.com/dreautall/waterfly-iii) de
*dreautall* (licencia MIT) y rediseña por completo la interfaz gráfica, **inspirándose en
la app de Fintonic** sobre una base **Material 3**.

## Características

- 🎨 **Interfaz estilo Fintonic** — navegación inferior con pestañas Inicio, Movimientos,
  Análisis y Huchas. Tarjetas de patrimonio, gráficos de barras y donuts, listados de
  categorías.
- 📴 **Offline-first** — caché inteligente con estrategia *stale-while-revalidate* y
  sintetización de respuestas API desde la base de datos local. La app funciona sin
  conexión.
- ⚡ **Carga instantánea** — precarga sincrónica al arranque y `initialData` en los
  `FutureBuilder` para que las pestañas se muestren sin spinners intermedios.
- 🔔 **Notificaciones** — listener de notificaciones bancarias para crear transacciones
  rápidamente.
- 🌍 **Multi-idioma** — 25 idiomas heredados del proyecto original, con interfaz principal
  en español.

## Compilación

```bash
flutter pub get
flutter gen-l10n
flutter build apk --debug
```

## Identificador de paquete

- Release: `com.asaezs.fireflytonic`
- Debug: `com.asaezs.fireflytonic.debug`

## Créditos y licencia

- Proyecto original: **waterfly-iii** — © 2023-2026 dreautall — licencia MIT.
- La integración con el API de Firefly III (`lib/generated/`) es código autogenerado.

Este proyecto se distribuye bajo la **licencia MIT** (ver [`LICENSE`](./LICENSE)), conservando
el aviso de copyright original tal como exige dicha licencia. La documentación original del
proyecto base se conserva en [`README.upstream.md`](./README.upstream.md) y [`FAQ.md`](./FAQ.md).

*Firefly III y Fintonic son marcas de sus respectivos propietarios. Este proyecto no está
afiliado ni respaldado por ellos.*
