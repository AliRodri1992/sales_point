# Adecuaciones de autenticación

Los cambios mantienen las pantallas y el registro de cinco pasos de Delta POS.
La validación de acceso devuelve errores de campo para datos incompletos o correo
inválido, y un rechazo genérico para credenciales incorrectas. La autenticación
sigue pasando por Warden/Devise; no se verifica la contraseña de forma paralela.

El wizard muestra el paso actual en móvil, conserva las etiquetas accesibles de
los cinco pasos y completa el resumen con tipo de implementación, zona horaria y
preferencias de migración. La zona horaria elegida se permite también en servidor.

Los controles mejorados conservan el select nativo para envío y validación,
ocultándolo únicamente de la representación accesible mientras está mejorado.
El botón visible refleja sus mensajes de error y el estado requerido.

## Documentos de aceptación pendientes

El repositorio no incluye documentos aprobados de términos ni privacidad y sus
enlaces de landing son marcadores `#`. No se crearon documentos ni rutas ficticias.

Configurar las URL HTTPS reales de documentos aprobados mediante:

- `DELTA_POS_TERMS_URL`
- `DELTA_POS_PRIVACY_URL`

El formulario enlaza cada documento configurado en una pestaña nueva con
`noopener noreferrer`, preservando los datos del registro. Si falta alguno,
solicita consultar al administrador antes de aceptar. Se conservan la aceptación
explícita y las validaciones actuales; no se marca la casilla automáticamente.

## Color y validación

`--brand-on-white` aporta un tono de la misma familia cuando el color original
no contrasta con texto blanco. Solo las acciones y enlaces de autenticación usan
ese tono; las marcas, muestras de tema y demás pantallas mantienen sus colores.
El tono predeterminado es `#047857` (contraste 5.48:1 con blanco).

Ejecutar las pruebas con `bash bin/overcommit-rspec` y los analizadores del
proyecto según AGENTS.md. Las pruebas JS requieren recompilar previamente los
assets. No se deben ejecutar contra la base de desarrollo.
