# Solicitud de demostración: adecuaciones visuales y funcionales

Pantalla: `/demo_requests/new`. Rama: `feature/fixes`.

## Cambios

- Un solo controlador coordina los pasos, la paleta y el cambio de idioma.
- Enter en los datos de contacto avanza al comercio y valida únicamente el paso actual.
- El servidor abre el primer paso con errores. Los mensajes siguen el formato «NombreCampo mensajeValidación», con identificadores y referencias ARIA que contienen el texto completo.
- Los límites de longitud se obtienen de los validadores del modelo; las correcciones eliminan los errores del campo en cuanto son válidas.
- El cambio de idioma conserva valores, país del teléfono, paso, tema y campos ya validados mediante un traspaso temporal en memoria para esa navegación Turbo. No se persisten datos de contacto en localStorage o sessionStorage. Una recarga completa no conserva el borrador.
- El selector telefónico utiliza las traducciones y la API de la versión instalada de intl-tel-input.
- Las 20 paletas actúan sobre el contenedor del formulario. Sus colores de acción se ajustan conservando el tono para alcanzar contraste AA con el texto blanco.
- Tema e idioma tienen nombres accesibles, estado expandido, navegación por teclado y retorno del foco. Los controles principales tienen una altura mínima de 44 píxeles.
- El documento admite desplazamiento natural en móvil y ventanas bajas; la barra de preferencias ocupa espacio propio y no se superpone al progreso.
- Los errores de conexión y HTTP mantienen los valores, restituyen el botón y muestran un único SweetAlert2 persistente con cierre manual. Se dispone de un mensaje accesible en la página si SweetAlert2 no está disponible. Una respuesta 422 conserva el tratamiento de errores del servidor.
- El enlace de privacidad abre un documento real en otra pestaña sin descartar el formulario.

## Página de privacidad

`/privacy` presenta un diseño con la marca existente, índice de secciones y versiones en español, inglés y coreano. El texto describe el flujo de solicitud de demostración y permanece identificado como borrador para revisión. No constituye una declaración de cumplimiento jurídico ni cubre todos los tratamientos de otros módulos.

Los datos iniciales proporcionados para el borrador son Kurosoft S.A. de C.V., Ivan Ali Rodriguez Vasquez y el domicilio indicado por el propietario. El correo `privacidad@kurosoft.example` es únicamente un ejemplo y no genera un enlace de envío.

Se admiten estas variables para completar o sustituir la información sin modificar la plantilla:

- `DELTA_POS_PRIVACY_RESPONSIBLE`: razón social del responsable.
- `DELTA_POS_PRIVACY_CONTACT_NAME`: persona de contacto.
- `DELTA_POS_PRIVACY_ADDRESS`: domicilio completo del responsable.
- `DELTA_POS_PRIVACY_EMAIL`: buzón real de atención; se valida antes de crear un enlace `mailto:`.
- `DELTA_POS_PRIVACY_URL`: documento HTTPS externo aprobado, si se prefiere al documento local. Se rechazan credenciales en la URL y esquemas inseguros; el respaldo es `/privacy`.

Antes de finalizar el aviso deben confirmarse el domicilio completo, el correo activo, los plazos de conservación, proveedores, transferencias y procedimiento de atención. La estructura se contrastó con la [LFPDPPP publicada por la Cámara de Diputados](https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf); los hechos sobre el flujo proceden del código de la aplicación.

## Verificación

Las pruebas de navegador ejercitan el avance con Enter, longitudes, corrección inmediata, cambio de idioma y país, contraste de las paletas, teclado, dimensiones reducidas, errores del servidor, red y HTTP 503. Las pruebas de solicitudes cubren creación válida, confirmación, 422, enlaces de privacidad y contenido seguro del nuevo documento. También se verifican regresiones en autenticación y navegación de la landing.

RSpec se ejecuta con `bash bin/overcommit-rspec` en un contenedor temporal aislado y una base de pruebas, sin modificar la base de desarrollo. Los fallos de envío se simulan dentro de esas pruebas; no se envían solicitudes comerciales desde la revisión visual. Se complementa con RuboCop, compilación de CSS/JS, auditoría I18n estricta y revisión visual en escritorio y móvil.

Resultado local (2026-11-02): 92 ejemplos RSpec, 0 fallos; RuboCop sin observaciones en los ocho archivos Ruby modificados; auditoría I18n estricta aprobada en 219 archivos; compilaciones CSS y JavaScript completadas. La compilación CSS conserva un aviso del CSS de intl-tel-input sobre `@position-try`, sin impedir la generación. La revisión visual confirmó el formulario a 1440×900 y 320×740; las pruebas también cubren 1440×500 y 768×600. No se realizó push ni se atribuyen estos resultados a GitHub Actions.
