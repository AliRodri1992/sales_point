# SweetAlert2 en Delta POS

El estilo compartido vive en `app/assets/stylesheets/components/sweetalert.css`.
Se aplica a `window.Swal`, las importaciones directas de SweetAlert2, los avisos
del servidor y las notificaciones Turbo Stream, sin dependencias externas.

- Superficie blanca, texto azul pizarra, tipografías locales Inter y Plus Jakarta Sans.
- Éxito en verde, error en rosa oscuro, advertencia en ámbar e información/pregunta en azul.
  Cada estado tiene además un icono distinto; el color no es la única señal.
- Los botones principales usan el tono accesible del tema (`--brand-on-white`),
  con verde esmeralda de respaldo. Cancelar tiene un estilo secundario y las
  confirmaciones destructivas mantienen el botón rojo.
- Los avisos breves son compactos y no bloquean la página. Los diálogos separan
  título, descripción y acciones. Los botones y campos tienen al menos 44 px de alto,
  foco visible y disposición adaptable a móvil. Se respeta movimiento reducido.

Usar las opciones habituales de SweetAlert2 (`icon`, `title`, `text`, `toast`,
`showCancelButton`, etc.). Evitar colores y estilos en línea en nuevos usos:
la apariencia debe proceder del componente común. Las confirmaciones Turbo
conservan su disposición contextual en `components/delta_confirm.css` y su
comportamiento en `swal_confirm_controller.js`.

La duración y los callbacks siguen perteneciendo a cada flujo. El rechazo de
credenciales permanece visible hasta cerrarlo y devuelve el foco a contraseña.
Las validaciones de campos continúan junto al campo correspondiente.
