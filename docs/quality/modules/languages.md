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
- **Estado:** cambios preparados para implementación/verificación, **NO CERRADO**. **SHA de aceptación:** PENDIENTE.

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
