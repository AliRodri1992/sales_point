# Adecuaciones de la landing

Se mantiene la identidad de Delta POS y se corrigen los problemas de la auditoría:

- La navbar conecta su controlador y usa navegación compacta hasta 1280 px,
  evitando comprimir la marca en tablet. El menú admite Escape, cierre exterior,
  cierre al navegar y restauración después de Turbo.
- Escritorio y móvil comparten el selector de idioma con identificadores únicos,
  foco, Escape, flechas, estado seleccionado y mensajes de error traducidos.
  El controlador conserva compatibilidad con los selectores de autenticación y administración.
- Las secciones reservan espacio para la cabecera al navegar por anclas.
- El panel ilustrativo apila sus tarjetas en móvil y usa un título comprensible.
- Las acciones principales conservan la familia esmeralda/teal con tonos más oscuros;
  los textos secundarios de precios son más legibles.
- Los testimonios avanzan únicamente al pulsar Anterior/Siguiente, con indicador
  anunciado y grupos inactivos ocultos. Sin JavaScript se muestran todos los testimonios.
- La demostración enfoca el primer campo inválido o el encabezado del paso;
  reconoce selects mejorados y evita buscar controles inexistentes en la pantalla de éxito.
- Los CTA de precios y el menú móvil dicen «Comenzar» y abren el registro existente.
  No se agrega una selección comercial ni un proceso de cobro.

Las etiquetas nuevas mantienen paridad entre español, inglés y coreano. El movimiento
reducido desactiva el desplazamiento suave y las transiciones de la landing.

Las pruebas de navegador cubren menú móvil/tablet, teclado e idioma, destinos,
anclas, tamaños de 320 a 1440 px, testimonios sin avance automático y foco del
formulario y confirmación de demostración. Las pruebas usan el runner aislado
`bash bin/overcommit-rspec`; la demostración de éxito se simula sin enviar correos.

Con sesión activa, todos los CTA de registro muestran «Ir al panel» y apuntan al
dashboard existente. La cabecera ofrece las iniciales y el nombre del usuario con
las opciones de cuenta ya implementadas (perfil, guía y cierre de sesión con DELETE).
El menú de cuenta funciona con teclado, cierra con Escape/clic exterior y mantiene
los permisos y rutas existentes. La landing sigue siendo pública y consultable.
La caché de vistas de Turbo se desactiva en la landing para consultar el estado
actual de sesión al volver con el historial después de iniciar o cerrar sesión.
