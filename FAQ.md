# FAQ

## Funcionalidad base

**P: ¿Cómo puedo duplicar una transacción existente?**

R: Mantén pulsada cualquier transacción y selecciona "Duplicar" en el menú contextual. Se
abrirá el formulario con toda la información, solo la fecha y hora se ajustarán a la actual.

**P: ¿Cómo uso un certificado SSL personalizado (autofirmado)?**

R: La app utiliza el almacén de certificados de Android. Puedes crear tu propia CA
(Autoridad Certificadora), generar tus certificados autofirmados y añadir el certificado
de la CA al almacén de Android. Cualquier certificado firmado por tu CA será aceptado.

**P: ¿Cómo reporto errores?**

R: Puedes reportar errores de dos formas:

1. **Envío de logs:** Ve a Ajustes, pulsa sobre el número de versión para activar los logs
   de depuración, reproduce el error, y luego envía los logs desde Ajustes (se abrirá tu
   app de email con los logs adjuntos).
2. **GitHub issue**: Crea un
   [nuevo issue](https://github.com/asaez85/Fireflytonic/issues/new) en el repositorio.

## Listener de notificaciones

**P: ¿Cómo funciona el listener de notificaciones?**

R: Cuando está activo, la app monitoriza las notificaciones entrantes que contengan un
valor monetario (algo como "*12,34 €*"). Si detecta una, te ofrece crear una nueva
transacción automáticamente.

**P: ¡He activado el listener pero mi app bancaria no aparece!**

R: Después de activar el listener, necesitas recibir al menos una notificación válida
(con importe) para que la app aparezca en la lista. Si sigue sin aparecer:

* Fireflytonic necesita estar preconfigurada para escuchar apps específicas. Abre un
  [issue](https://github.com/asaez85/Fireflytonic/issues/new) indicando el nombre y
  el enlace de Play Store de la app bancaria.
* A partir de Android 15, Google puede ocultar notificaciones que contengan códigos de un
  solo uso. Para usuarios avanzados:
  `adb shell appops set com.asaezs.fireflytonic RECEIVE_SENSITIVE_NOTIFICATIONS allow`

**P: ¡La app selecciona la moneda incorrecta!**

R: Suele pasar con monedas que comparten el símbolo `$`. La app busca coincidencia exacta.
Puedes cambiar los símbolos en los ajustes de moneda de Firefly III (por ejemplo, cambiar
el Dólar USA a `US$`).

## Varios

**P: ¿Dónde está la política de privacidad?**

R: La app solo envía datos al servidor Firefly III que configures. No hay anuncios,
rastreo ni analíticas. La política de privacidad completa está en
[`.playstore/privacy-policy.md`](./.playstore/privacy-policy.md).
