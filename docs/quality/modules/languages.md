# Estándar de calidad — Idiomas (Delta POS)

Rama: `feature/fixes` · Alcance: `/admin/languages`, selector y traducciones I18n.

- **Estado:** CAMBIOS PUBLICADOS; VERIFICACIÓN FOCALIZADA **PASÓ**; CI GLOBAL / ACEPTACIÓN VISUAL **PENDIENTES**; **NO CERRADO**.
- **SHA de implementación inicial:** `cca3b028359320682585e6d1712be2d06d295a60`.
- **SHA focalizado verificado:** `b9a6d576920bab9d2cfb4d8955205a792f7fafbe`.
- **SHA de aceptación global:** **PENDIENTE**.
- **Evidencia RSpec focalizado:** **PASÓ**, 82 ejemplos y 0 fallos (modelos, peticiones y navegador en Chrome).
- **Evidencia RuboCop focalizado e I18n/YAML:** **PASÓ**.
- **Evidencia de ejecución:** [Languages CI #42623183766](https://github.com/AliRodri1992/sales_point/actions/runs/42623183766).
- **Migraciones en CI focalizado:** **PASÓ** para el SHA verificado.
- **Auditoría visual manual WCAG / responsive 320, 390, 768, 1440 / lector de pantalla:** **PENDIENTE**; hubo dos escenarios automatizados de navegador, no una revisión visual exhaustiva.
- **CI global e inspección independiente:** **PENDIENTE**; los jobs globales de `feature/fixes` se cancelaron repetidamente por commits de otros módulos.

## Registro de hallazgos

| ID | Severidad | Causa / impacto | Adecuación | Verificación |
|---|---|---|---|---|
| IDI-001 | Alta | Catálogo activo no equivale a locale configurado. | Solo se activan códigos de `I18n.available_locales`; los no configurados pueden conservarse inactivos. | `language_spec`, `languages_spec` |
| IDI-002 | Alta | YAML precedía a las traducciones de BD; un override no tenía efecto. | BD primero con YAML de respaldo. | `translate_spec` |
| IDI-003 | Alta | El backend memorizaba indefinidamente las traducciones. | Revisiones de caché por proceso y almacén compartido; recarga atómica. | `translate_spec` |
| IDI-004 | Media | La clave editable podía desvincular preferencias e historial. | Identificador inmutable al actualizar y de solo lectura en el formulario. | `language_spec`, `languages_spec` |
| IDI-005 | Alta | El idioma predeterminado podía retirarse y quedar sin fallback activo. | Bloqueo en modelo, controlador y acción destructiva de la lista. | `language_spec`, `languages_spec` |
| IDI-006 | Media | Formulario dependía de `required` de HTML5 y select nativo. | Validación de modelo, ARIA asociado al error y dropdown Delta. | Revisión de vista y requests |
| IDI-007 | Media | Selector administrativo no marcaba `aria-pressed` ni mensajes localizados de error. | Estado accesible y manejo de error localizado. | Revisión de componentes y requests |
| IDI-008 | Media | Importadores de traducciones solo reconocían pocos nombres; setup buscaba dependencia ausente. | Se importan archivos `es/en/ko` con prefijo o sufijo, se corrige ruta y dependencia. | Tareas y setup |
| IDI-009 | Media | Se verificaba unicidad de traducciones únicamente en alta. | Verificación también al actualizar. | `translate_spec` |

## Contratos de integración

- `Language.selectable`: activo, no eliminado y permitido por Rails.
- `PATCH /language`: conserva preferencia de sesión, cookie y usuario solo para idiomas seleccionables.
- `Translate`: datos activos y únicos por idioma + clave; invalida caché tras el commit.
- `I18n.backend`: BD antepone los overrides al YAML; YAML mantiene el sistema disponible si falla la BD.
- Los códigos de idioma no pueden modificarse después del alta; `es` continúa siendo obligatorio mientras sea el idioma predeterminado.
- Cambios circunscritos a Idiomas y sus dependencias directas.

## Validación y límites

Los hallazgos solo se consideran cerrados después de ejecutar RSpec, RuboCop,
verificar CI y reauditar las pantallas. La revisión estática no sustituye
pruebas visuales, accesibilidad con teclado ni pruebas en un navegador real.

Los archivos `config/locales` son una fuente de traducciones separada de los
registros del catálogo. La carga admite todos los módulos identificables,
pero **no garantiza que cada cadena esté traducida correctamente**. La
paridad semántica de contenido es una auditoría de traducción independiente.

## Evidencia de reauditoría — 2026-11-09

En el SHA `b9a6d576920bab9d2cfb4d8955205a792f7fafbe`:
- **PASÓ:** `Languages module RuboCop`.
- **PASÓ:** `Languages locale integrity` (paridad YAML y registro modular).
- **PASÓ:** `Languages requests, models and browser` (82 ejemplos, 0 fallos, con Chrome).
- Los casos de inserción de idioma no admitido, código inmutable, protección del idioma predeterminado, preferencia de usuario/sesión, overrides de traducción y regresión de interfaz **PASARON** en esa batería.
- IDI-001 a IDI-009: **IMPLEMENTADOS**; sus comportamientos cubiertos por RSpec y los dos escenarios de navegador **PASARON**. La ejecución independiente de scripts de carga (IDI-008), el comportamiento del selector con lector de pantalla/teclado (IDI-007) y la evaluación visual/manual completa (IDI-006/007) permanecen **PENDIENTES**. No atribuir a esas áreas una prueba que no se ejecutó.
- Los fallos de los flujos anteriores provinieron de un `db/schema.rb` temporalmente corrupto durante trabajos paralelos y de la preparación del usuario/membresía en `languages_diagnostic_spec.rb`. Se corrigió la preparación y las 82 pruebas del flujo final pasaron.
- El resultado de la batería focalizada **no prueba** la ausencia de problemas en el CI global ni certifica WCAG/UX manual. **NO CERRADO**.

## Auditoría visual y rediseño — 2026-11-09 (segunda revisión)

- **Alcance:** `GET /admin/languages`, listado y filtros, `new/edit/show`, mensajes de validación, acciones y sus contratos con el selector. No es una auditoría global del sistema de traducciones.
- **Método:** procedimientos AI Dev Suite `impeccable-audit`, `ui-ux-pro-max` y `ponytail-engineering`, por inspección de Rails/ERB/Stimulus/CSS y preparación de pruebas. **No se ejecutaron** las CLIs externas de Impeccable, UI UX Pro Max ni Ponytail.
- **Base de inspección:** rama `feature/fixes`, SHA `8d0a2b65b6a19e8cec68948adcbb0ebd014921fd`.
- **Evidencia visual:** el navegador conectado solo ofrecía una pestaña de Productos; no hubo navegación autenticada a Idiomas ni capturas previas. Los hallazgos son **confirmados en código**, no reproducidos visualmente.
- **Estado:** REDISEÑO IMPLEMENTADO y pruebas focalizadas **PASARON**; inspección visual completa y aceptación global **PENDIENTES**. **NO CERRADO**.
- **SHA del rediseño:** `653c67beb39a454fc470cc49b994cecdadcf3f42`.
- **Evidencia focalizada:** [Languages CI #42756958104](https://github.com/AliRodri1992/sales_point/actions/runs/42756958104), **PASÓ** (87 RSpec, 0 fallos, Chrome, RuboCop e I18n).
- **Evidencia global:** [CI #42756958439](https://github.com/AliRodri1992/sales_point/actions/runs/42756958439): **FALLÓ** solo RSpec (prueba N+1 de Clientes `spec/performance/n_plus_one_scaling_spec.rb:51`); RuboCop, seguridad, I18n y migraciones limpias con semillas **PASARON**. Fallo **EXTERNO** a Idiomas, no cerrado.

| ID | Prioridad | Evidencia / causa raíz | Adecuación prevista | Validación |
|---|---|---|---|---|
| IDI-010 | P2 | `index.html.erb` usa `submit_tag` (input submit); `catalog_workspace.css` aplica `width:100%` a `.catalog-filter input`, agrandando el CTA de filtros | Eliminar submit visible con JS; autoaplicar búsqueda y estatus; conservar botón compacto sin JS | RSpec requests + navegador |
| IDI-011 | P2 | `languages_search_controller.js` existe pero el formulario no lo conecta; interacción requiere pulsar botón | Conectar Stimulus con debounce, cambio inmediato de estado y soporte de composición de texto | RSpec navegador y teclado |
| IDI-012 | P2 | Filtros sin etiquetas activas; el cero filtrado anuncia “No languages yet”, aunque el catálogo tenga datos | Chips removibles, limpiar filtros, estado sin coincidencias separado del catálogo vacío | Requests y navegador |
| IDI-013 | P2 | Tabla de cinco columnas y acciones puede provocar scroll horizontal y pérdida de contexto móvil | Cuatro columnas en escritorio, fila de identidad con bandera; tarjetas móviles y acciones accesibles | Browser 390px, 320px pendiente |
| IDI-014 | P3 | Formulario de cuatro campos ocupa `catalog-layout` con sidebar fijo de 280px y ayuda redundante | Formulario centralizado y compacto con texto contextual; detalle con jerarquía y etiquetas | Inspección y navegador |
| IDI-015 | P2 | Estado del idioma predeterminado parece editable en formulario aunque el modelo rechaza desactivación | Deshabilitar selector de estado predeterminado y explicar la razón | Requests/modelo y navegador |
| IDI-016 | P3 | Búsqueda no limita longitud del query y el filtro de estatus no valida contra la enumeración | Limitar término de búsqueda y usar lista blanca de estados | Requests |
| IDI-017 | P2 | Cobertura focal no verifica el nuevo flujo de filtros ni la presentación móvil | Agregar pruebas de request y escenarios reales de Chrome | Languages CI |

**Criterio de cierre:** ejecutar los nuevos escenarios con Chrome y RSpec, RuboCop, I18n/YAML y CI global sobre el SHA publicado; recorrer manualmente 320/390/768/1440 px, foco, teclado, contraste y zoom 200%; revisión independiente. Mantener el estándar de formularios (errores individuales por modelo, sin duplicados ni `required` HTML5).

**Frontera:** las tareas de normalización global de YAML, permisos, onboarding y otros catálogos pertenecen a sus propios expedientes. No se modifican en este rediseño.

### Reauditoría de los hallazgos nuevos

- **IDI-010:** eliminado el `submit_tag` ancho. La búsqueda/estatus se aplican automáticamente; el fallback `<noscript>` usa un botón compacto. Request spec **PASÓ**.
- **IDI-011:** Stimulus con debounce de 350 ms, cambio de estado inmediato y soporte de composición de texto. Browser spec **PASÓ**.
- **IDI-012:** etiquetas activas eliminables, limpiar filtros y distinción entre catálogo vacío/sin coincidencias. Requests y browser specs **PASARON**.
- **IDI-013:** tabla de cuatro columnas y tarjetas móviles. Browser spec a 390px **PASÓ**; 320/768/1440 y zoom 200% requieren recorrido visual manual.
- **IDI-014:** formulario compacto y detalle más legible. Render y comportamiento cubiertos indirectamente por specs; **aceptación visual manual pendiente**.
- **IDI-015:** control de estatus bloqueado visualmente para el idioma predeterminado (el modelo ya lo protege). Verificar con teclado en aceptación visual.
- **IDI-016:** estado validado contra enum; búsqueda limitada a 100 caracteres. Revisado en código.
- **IDI-017:** 3 request specs y 2 escenarios de navegador nuevos; **87 ejemplos, 0 fallos**.

**Resumen:** no hay regresiones conocidas dentro de la batería focalizada de Idiomas. El hallazgo de rendimiento N+1 de Clientes sigue en su propio módulo; no modificar Clientes en esta auditoría. Sin revisión manual del renderizado/lector de pantalla, no se certifica WCAG ni se declara cerrado el módulo.


## Auditoría de interacción — Crear y editar en modal (2026-11-09)

- **Alcance:** `/admin/languages/new`, `/admin/languages/:id/edit`, guardar con validaciones, accesibilidad del diálogo, preservación de filtros del listado y actualización visual después de editar.
- **Contexto:** formulario reducido a nombre, código ISO de idioma, bandera y estado. El sistema ya incorpora `language_modal` en el layout, pero sus enlaces conducían a páginas completas; se mantienen las rutas independientes como respaldo sin JavaScript.
- **Método AI Dev Suite:** `impeccable-audit`, `ui-ux-pro-max` y `ponytail-engineering` aplicados como metodología de inspección de código y pruebas. No se ejecutaron las CLIs externas.
- **SHA de revisión:** `986e951f79679f9799792690d8d528ec54f019e8`.
- **Estado:** IMPLEMENTADO y VERIFICADO EN PRUEBAS FOCALIZADAS; **NO CERRADO** por verificación visual manual y puerta de CI global.
- **Commit de implementación:** `4de529d5f1a93522f2a5bba83830b27eeca7b52a`.
- **Languages CI:** [ejecución #42758496663](https://github.com/AliRodri1992/sales_point/actions/runs/42758496663) **PASÓ**; 94 ejemplos RSpec (Chrome, requests, modelos), 0 fallos, RuboCop e integridad de traducciones aprobados.
- **CI global:** [ejecución #42758496722](https://github.com/AliRodri1992/sales_point/actions/runs/42758496722) con escaneo de seguridad e I18n aprobados a la fecha de registro; comprobación global restante en proceso.
- **Puerta visual:** **PENDIENTE** de revisión manual 320/390/768/1440, teclado, zoom 200 % y lector de pantalla.

| ID | Prioridad | Evidencia por código | Adecuación | Verificación |
|---|---|---|---|---|
| IDI-018 | P2 | Los enlaces de Crear/Editar tienen `data-turbo-frame="_top"` y no usan el diálogo disponible | Dirigir las acciones al frame `language_modal` | Nuevos specs de request y Chrome |
| IDI-019 | P1 | `_form.html.erb` fija `turbo:false` mientras las respuestas exitosas incluyen `turbo_stream.update "language_modal"` | Enviar formularios de modal mediante Turbo; conservar modo HTML independiente | Crear/editar vía Turbo y fallback sin JS |
| IDI-020 | P2 | Cancelar navega al listado desde el modal, con riesgo de perder los filtros y contexto | Cancelar cierra el diálogo sin navegación | Browser Escape/cancelar |
| IDI-021 | P2 | `language_modal` no incluye la acción `modal#trap` que sí existe en otras modales | Trampa de foco, Escape, cierre por fondo y retorno de foco | Chrome + auditoría manual |
| IDI-022 | P2 | Errores 422 al editar no tienen prueba del flujo dentro del frame | Renderizar 422 HTML con errores individuales dentro del mismo modal | Request y Chrome |
| IDI-023 | P3 | El formulario pequeño se muestra en un panel más amplio de lo necesario | Diálogo centrado y compacto, adaptable y con título/botón Cerrar | Chrome y revisión manual |

**Contratos protegidos:** Pundit, validaciones del modelo, idioma predeterminado, notificaciones, SweetAlert2, traducciones es/en/ko y rutas HTML normales. En un error 422 no se deben perder los datos introducidos ni cerrar el diálogo. Los cambios realizados con filtros activos deben conservar su contexto. Editar desde detalle debe actualizar la información visible.

**Aceptación:** comprobar el SHA publicado con Languages CI (RSpec, Chrome, RuboCop, I18n/YAML); comprobar el CI global y registrar errores externos sin modificar módulos vecinos. Inspección visual manual, 320/390/768/1440, zoom 200 %, teclado y lector de pantalla pendientes hasta contar con un navegador accesible.

### Reauditoría de modal — Evidencia y límites

- **IDI-018**: links Crear/Editar usan el frame `language_modal` desde listado y detalle; requests y navegador **PASARON**.
- **IDI-019**: el formulario dentro del modal usa Turbo; el formulario de página independiente conserva envío HTML. Creación y actualización dentro del diálogo **PASARON**.
- **IDI-020**: Cancelar es botón de cierre del modal, no enlace de navegación; Chrome verificó cierre mediante Escape sin abandonar el listado. Clic específico en Cancelar pendiente de inspección manual.
- **IDI-021**: se habilitó trampa de foco `keydown.tab->modal#trap` como en otras pantallas del sistema. Chrome probó Escape; comprobación con lector de pantalla y recorrido completo de Tab **PENDIENTE**.
- **IDI-022**: errores HTTP 422 se devuelven en HTML dentro del mismo frame; solicitudes y Chrome **PASARON** sin descartar datos.
- **IDI-023**: ancho máximo 36rem con botón Cerrar, título, ayuda contextual y scroll del overlay. Validación funcional en Chrome **PASÓ**; inspección estética visual manual **PENDIENTE**.
- **Integridad adicional:** el detalle puede actualizar su información visible tras editar gracias al Turbo Stream `language_detail_panel`, sin afectar el listado cuando el destino no existe.
- **Frontera:** auditoría exclusivamente de Idiomas y su integración modal. Hallazgos externos del CI global se registrarán con sus propietarios, no se corregirán en este expediente.

**No se declara el módulo cerrado** hasta contar con la puerta global, accesibilidad verificable y revisión visual manual. Las pruebas focalizadas sí acreditan el flujo funcional de los nuevos modales en el SHA de implementación.

## Auditoría de densidad y proximidad de acciones — 2026-11-09

**Alcance estricto:** tamaño y distribución del modal de `new/edit` y ubicación de «Nuevo idioma» respecto de los filtros en `/admin/languages`. No se revisaron permisos, impuestos, Clientes u otros módulos.

**Procedimiento:** inspección estática de ERB/CSS con criterios AI Dev Suite (`impeccable-audit`, `ui-ux-pro-max` y `ponytail-engineering`). Los ejecutables externos no se usaron.

| ID | Prioridad | Evidencia | Adecuación | Regresión |
|---|---|---|---|---|
| IDI-024 | P3 | El panel tiene `max-w-xl` y `width: min(100%, 36rem)`; en escritorio limita el espacio disponible | Ampliar a `max-w-2xl` y `42rem`, manteniendo ancho adaptable a móvil | Chrome mide el ancho real a 1280 px |
| IDI-025 | P3 | `.languages-editor__fields > :first-child` ocupa toda la fila, generando tres filas de cuatro campos dentro del modal | Usar cuadrícula de dos columnas y dos filas para formulario modal en escritorio; una columna debajo de 640 px | Chrome comprueba columnas a 1280 y 390 px |
| IDI-026 | P3 | «Nuevo idioma» está alineado con el encabezado principal, visualmente separado de la búsqueda | Colocar la acción dentro del panel de filtros, junto a su encabezado; conservar autorización y `language_modal` | Requests verifican ubicación y Turbo Frame; Chrome verifica botón visible |
| IDI-027 | P3 | CSS usaba `.language-modal-panel` pero el panel real es `.languages-modal-panel`; la regla de ancho podía quedar inactiva | Unificar el selector CSS con la clase real del modal | Chrome mide ancho y columnas reales |

**Criterios de aceptación:** sin doble botón, sin desbordamiento horizontal del modal a 390 px, controles accesibles y espaciado consistente con Delta POS. La altura se reduce por distribución de filas; no se garantiza un número de píxeles de alto sin medición. Las rutas, la validación y las traducciones del modal permanecen intactas.

**Estado:** adecuaciones implementadas y CI focalizado **APROBADO** sobre `04e0c07bb69bb6cf28d700b4e9169ad907c5408b`; **96 ejemplos RSpec, 0 fallos**, incluidas pruebas con Chrome a 1280/390 px. RuboCop e integridad I18n también **APROBARON**. [Languages CI #42759737811](https://github.com/AliRodri1992/sales_point/actions/runs/42759737811). CI global del commit **CANCELADO** por commits concurrentes en la misma rama; inspección visual manual de accesibilidad/zoom todavía **PENDIENTE**. **NO CERRADO FORMALMENTE**.


## Auditoría correctiva de proximidad — IDI-028 (2026-11-09)

**Alcance:** exclusivamente la posición del botón «Nuevo idioma» respecto al panel de filtros en `/admin/languages`.

| ID | Prioridad | Hallazgo confirmado | Corrección | Aceptación |
|---|---|---|---|---|
| IDI-028 | P3 (UX) | La adecuación anterior IDI-026 colocó por error «Nuevo idioma» **dentro** del panel `.languages-filters`, aunque se había pedido ubicarlo **un poco arriba** del panel. | Acción en `.languages-actions-bar` como hermana anterior inmediata de `section.languages-filters`, alineada a la derecha con margen inferior de `0.625rem` (10 px). El encabezado del panel conserva solamente «Filtros de idiomas». | Request spec verifica DOM exterior, botón único y destino Turbo; Chrome verifica que el botón quede 0–16 px encima del panel y alineado con su borde derecho. |

**Invariantes:** el botón sigue protegido por `policy(Language).create?`; el destino continúa siendo el Turbo Frame `language_modal`; no se alteran rutas, controladores, modelo, textos ni las modales de creación/edición. El formulario de filtros mantiene su comportamiento automático y accesible.

**Método:** auditoría del código con criterios de AI Dev Suite (`impeccable-audit`, `ui-ux-pro-max`); no se ejecutaron sus CLIs externas. **Estado:** corrección **IMPLEMENTADA Y VERIFICADA** en `62f14bbbd4f17ebb0128a9df43b2e32ea5179480`. [Languages CI #42760889246](https://github.com/AliRodri1992/sales_point/actions/runs/42760889246) **APROBÓ**: 96 ejemplos RSpec, 0 fallos (incluido Chrome con verificación de posición); RuboCop y la integridad de traducciones también aprobaron. CI global del mismo commit aún pendiente en el momento de registrar la evidencia. La revisión visual manual, zoom 200 % y lector de pantalla continúan **PENDIENTES**, por lo que la auditoría **NO ESTÁ CERRADA FORMALMENTE**.

## Corrección de alineación de descripción y acción — IDI-029 (2026-11-09)

**Hallazgo IDI-029 (P3, UI):** ubicar «Nuevo idioma» en una barra independiente justo encima del panel de filtros dejó el subtítulo «Administra los idiomas disponibles en Delta POS.» aislado arriba del botón, alterando la jerarquía vertical. La necesidad expresada es mantener el subtítulo **en su ubicación habitual inmediatamente bajo el título** y presentar el botón a la **derecha, en esa misma fila**. Ambos deben permanecer **fuera del panel de filtros**.

**Corrección:** `languages-description-row` agrupa subtítulo y enlace; se eliminó la barra separada `languages-actions-bar`. La fila está alineada verticalmente, conserva el enlace con permisos Pundit y destino `language_modal`, y permite ajuste flexible en pantallas pequeñas. El encabezado sigue inmediatamente antes del panel de filtros.

**Verificación añadida:** un request spec comprueba estructura, traducción del subtítulo, botón único y separación del panel; un escenario Chrome comprueba centros verticales coincidentes, proximidad al panel, alineación a la derecha y apertura del modal. No se alteraron formularios, modelos, controladores ni traducciones.

**Estado:** cambio preparado; CI focalizado y revisión visual manual pendientes. Se mantiene **NO CERRADO** hasta verificar los resultados.


## Auditoría integral de revalidación — 2026-11-10

**Alcance:** `/admin/languages` listado, filtros, orden/paginación, show, modales new/edit, eliminación, selector de idioma, reglas de modelo, Pundit, persistencia de traducciones y CI. **Método:** lectura cruzada de ERB/CSS/Stimulus/Rails, modelos, políticas, tareas, specs, expediente y logs GitHub Actions; consulta de texto de la pestaña autenticada abierta `http://localhost:3000/admin/languages` (3 idiomas). Procedimientos metodológicos AI Dev Suite `impeccable-audit`, `ui-ux-pro-max` y `ponytail-engineering`. **No se han ejecutado sus CLIs externas**, ni se controló el navegador con clicks o captura de pantalla.

**SHA base de la inspección del código:** `b09ea4c4152fed58a0dee313603d4c154149cf75`; el HEAD de `feature/fixes` recibe commits paralelos de otros módulos. El hallazgo IDI-029 no se reabre: la estructura en `index.html.erb` coloca el subtítulo y el botón «Nuevo idioma» en la misma fila mediante `.languages-description-row`, **fuera** de filtros. El código del modal es compacto (42rem, 2 columnas >=640px, 1 columna móvil).

### Hallazgos de esta auditoría

| ID | Prioridad | Tipo / evidencia | Impacto y adecuación propuesta | Estado |
|---|---|---|---|---|
| **IDI-030** | **P2** | **Defecto confirmado en código:** `app/views/admin/languages/_row_actions.html.erb` envía DELETE a `admin_language_path(language)` **sin** `request.query_parameters`, mientras `Admin::LanguagesController#destroy` invoca `load_languages` y el Turbo Stream reemplaza `languages_list`. En contraste, new/edit sí pasan parámetros de consulta. | Si se elimina desde una lista filtrada/paginada, se recompone una lista no filtrada y el panel de búsqueda/estado queda desincronizado. Conservar y validar filtros/orden/página en DELETE, reajustar página si desaparece la última fila y añadir request+Chrome regression. | **ABIERTO** |
| **IDI-031** | **P2** | **Defecto de navegación fundamentado en código:** `ApplicationHelper#sort_link` y `PaginationHelper#pagination_link` enlazan a `languages_list` sin `data-turbo-action=\"advance\"` ni un `turbo-action` del frame. La búsqueda está en un formulario fuera del frame y sus campos `sort/direction` se generan solo con el GET de la página completa. | Orden y página cambian dentro del frame pero el historial/URL y los campos de filtro pueden no reflejarlo; recarga y atrás/adelante pueden perder estado. Mantener un origen de verdad para parámetros y verificar historial y búsqueda tras ordenar/paginar con Chrome. | **ABIERTO** |
| **IDI-032** | **P2** | **Defecto de guardas en controlador compartido:** `app/javascript/controllers/modal_controller.js#close` ejecuta `hide()` para Escape sin verificar `this.isOpen`. El layout conecta `keydown.esc@window` en `language_modal`, `category_modal` y `unit_of_measure_modal` simultáneamente. | Un Escape puede ejecutar `hide()` en instancias cerradas, cambiar `overflow-hidden` y mover el foco al primer enlace; el efecto final depende del orden de callbacks. Introducir guarda `isOpen`, evitar cierres duplicados y probar restauración de foco del modal Idiomas sin regresiones en modales vecinos. **No se ha reproducido manualmente.** | **ABIERTO, impacto inferido del código** |
| **IDI-033** | **P2** | **Riesgo de coherencia en desarrollo:** `config/environments/development.rb` usa `:memory_store`; `Translate.cache_revision` usa `Rails.cache` y estado local para invalidación entre procesos. Producción usa `:solid_cache_store`. | Si web y Sidekiq/u otros procesos comparten traducciones en desarrollo, una modificación en uno no se propaga mediante el cache local del otro. Establecer cache compartido en entornos multi-proceso o invalidación independiente y prueba entre procesos. **No se observó fallo real.** | **ABIERTO, riesgo condicionado al despliegue** |
| **IDI-034** | **P2** | **Riesgo de pérdida de personalizaciones:** `translations:load` llama a `Translate.load_from_file`, que ejecuta `update!(value: value.to_s)` incondicionalmente para cada clave hallada. | Reimportar archivos YAML reemplaza overrides actuales en PostgreSQL. Definir política explícita (no sobrescribir por defecto, modo forzado/dry run) y pruebas para conservar overrides. La importación independiente de extremo a extremo sigue sin verificarse. | **ABIERTO** |
| **IDI-035** | **P3** | **Pulido UX, no defecto funcional:** con 3 idiomas renderizados el listado todavía ofrece selector de 5/10/15/25/50 registros. | Se puede ocultar control de tamaño/paginación cuando no aporta valor, manteniendo soporte al crecer el catálogo y la preferencia por usuario. | **RECOMENDACIÓN** |
| **IDI-036** | **P2** | **Brecha de pruebas:** las specs actuales cubren éxito de create/edit, error 422, Escape, filtrado y modal a 390px, pero no DELETE bajo filtros, recarga/atrás tras ordenar, permisos denegados, foco restaurado tras Esc/cancelar, 320/768/1440, zoom 200% ni lectores de pantalla. | Añadir regresiones por riesgo antes de declarar el módulo cerrado. No atribuir una verificación manual o WCAG AA que no se ejecutó. | **ABIERTO** |

### Controles que sí constan implementados

- Autorización Pundit por acción (catalog policy), autenticación y control de estatus de cuenta.
- Locale activo restringido a `I18n.available_locales`; `Language.selectable` excluye idiomas inactivos/retirados; código inmutable; idioma predeterminado no se puede desactivar ni retirar mediante validaciones.
- Modal Turbo de create/edit con errores debajo de campos, cierre por Escape y botones Cancelar; opción HTML independiente; selector Delta sin buscador para estado; i18n es/en/ko.
- Filtros automáticos con debounce, chips de filtros activos, listado responsive y mensajes diferentes para catálogo vacío/sin coincidencias.
- Esquema PostgreSQL con índice único activo en `languages.code` e índice único activo para `translates(language_id,key)`.

### Verificaciones independientes y puerta de cierre

- **Último Languages CI focalizado consultado:** [#42764652306](https://github.com/AliRodri1992/sales_point/actions/runs/42764652306) en SHA `bf38d06877...`: **3 jobs verdes**, incluidos **96 ejemplos, 0 fallos**, RuboCop e I18n. Es evidencia de ese SHA, no prueba todos los commits posteriores de otros módulos.
- **CI global del HEAD inspeccionado:** [#42765356138](https://github.com/AliRodri1992/sales_point/actions/runs/42765356138) SHA `b09ea4c415...`: **no aprobado** por una prueba de rendimiento N+1 de **Clientes** (`spec/performance/n_plus_one_scaling_spec.rb:51`, `expected >=1, got 0`); seguridad, RuboCop, auditoría I18n/YAML y migraciones+semillas **aprobaron**. No atribuir el fallo de Clientes a Idiomas.
- **Comprobación visual disponible:** lectura del contenido HTML/textual del navegador conectado en localhost, sin captura de pantalla ni inspección de tamaños/contraste renderizados y sin interacción de teclado. Las pruebas de Chrome de CI sí son ejecuciones reales automatizadas pero no acreditan lector de pantalla o toda la accesibilidad.
- **Criterios faltantes:** corregir o justificar IDI-030/031 y la guarda de modal, blindar importaciones/invalidación multi-proceso, añadir pruebas y pasar CI global más revisión visual/teclado/zoom/lector de pantalla. No reconstruir base de datos ni tocar Clientes dentro de Idiomas.

**Estado formal de la auditoría: HALLAZGOS ABIERTOS — NO CERRADO.** Esta reauditoría es diagnóstica: **no se han modificado archivos funcionales ni se ha fusionado ninguna rama**.

## Implementación de los hallazgos IDI-030 a IDI-036 — 2026-11-10

**Rama:** `feature/fixes`. **Alcance:** Idiomas y dependencias directas (controlador compartido de modales y configuración de caché de desarrollo). Se preserva el encabezado: subtítulo y botón «Nuevo idioma» en la misma fila, fuera de filtros.

| ID | Adecuación incorporada | Prueba / condición de aceptación |
|---|---|---|
| IDI-030 | La acción DELETE transmite `request.query_parameters`; la respuesta Turbo Stream recupera la lista con filtros/orden/página y `paginate` limita la página efectiva si se elimina su última fila; la redirección en fallos conserva también los filtros. | Request: eliminación con búsqueda/estado/orden y recálculo de página. Browser: desaparición del registro sin perder controles. |
| IDI-031 | Los enlaces de orden/paginación **solo en Idiomas** usan `data-turbo-frame="_top"`, promoviendo navegación normal Turbo Drive y sincronizando URL, búsqueda y filtros (sin modificar helpers compartidos). | Request: verificar enlaces, Browser: ordenar y volver atrás. |
| IDI-032 | `modal_controller.js` ignora Escape y clic exterior cuando el modal está cerrado; no vacía marcos ni roba foco de otros componentes. | Browser: Escape en búsqueda cerrada, Cancelar en modal abierto y devolución de foco. |
| IDI-033 | `config/environments/development.rb` usa `:redis_cache_store` con `REDIS_URL` y namespace exclusivo, aprovechando Redis disponible en `docker-compose.dev.yml`. Rails y Sidekiq comparten el token de revisión de traducciones. | Modelo: lectura de una revisión publicada en caché compartida simulada. **Pendiente:** prueba real entre procesos web/Sidekiq en entorno de desarrollo conectado. |
| IDI-034 | `Translate.load_from_file` preserva valores existentes; únicamente `overwrite: true` los reemplaza. Permite `dry_run: true`. El Rake task expone `OVERWRITE=1`, `DRY_RUN=1`. Los seeds respetan overrides persistidos. | RSpec: primera importación, override intacto, reemplazo explícito y dry run sin escrituras. |
| IDI-035 | Selector «Mostrar» y enlaces de paginación se ocultan si hay como máximo el tamaño mínimo de página y solo una página de resultados, manteniéndolos al crecer el catálogo. | Request: catálogo pequeño y página con más registros; Browser responsive. |
| IDI-036 | Nuevos request specs: permisos denegados, DELETE con filtros, navegación, paginación reducida y pequeña. Chrome: eliminación filtrada, ordenación+historial, Escape/Cancelar con foco y anchos 320/768/1440. | Ejecutar Languages CI completo; contraste visual/lector de pantalla y zoom al 200 % **requieren validación manual**, no sustituidos por specs. |

**Uso de importación:**
```bash
bin/rails translations:load                 # Importa claves que aún no existen; conserva personalizaciones
DRY_RUN=1 bin/rails translations:load       # Recorre los archivos sin escribir en PostgreSQL
OVERWRITE=1 bin/rails translations:load     # Reemplaza explícitamente los valores existentes con YAML
```

La importación forzada puede sobrescribir personalizaciones; usar solo después de respaldo y revisión del archivo. El modo sin `OVERWRITE` no modifica los overrides.

**Estado de aceptación:** cambios de código y regresiones preparados para CI en el momento de escribir; **NO declarar aprobados** RSpec, RuboCop, migraciones ni revisión visual antes de verificar los resultados concretos. No tocar la prueba de rendimiento ajena de Clientes ni fusionar ramas hasta cumplir la puerta global.
