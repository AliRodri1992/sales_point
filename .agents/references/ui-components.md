# Catálogo UI Delta Emerald — patrones observados

## Componentes existentes
- `categories_workspace.css`: `.categories-page-header`, `.categories-primary-button`, `.categories-secondary-button`, `.categories-filter-panel`, `.categories-table`, `.categories-modal`, `.categories-empty-state`.
- `branch_workspace.css`: `.branch-workspace`, `.branch-row-actions`, `.branch-icon-button`, `.branch-mobile-list`, `.branch-form-layout` y estados de validación.
- `application.tailwind.css`: `.input-field:focus`, `.btn-submit-dynamic`, `#adminSidebar`, `#adminTopbar` y estados responsive.

## Reglas para cambios nuevos
1. Reutilizar patrones existentes antes de introducir variantes; no copiar clases de un módulo a otro sin revisar el contrato.
2. Botones: default/hover/focus-visible/active/disabled/loading; distinguir acción primaria, secundaria y destructiva.
3. Formularios: etiquetas explícitas, errores de servidor asociados mediante `aria-invalid` y `aria-describedby`; evitar saltos de layout y no confiar solo en HTML5 `required`.
4. Tablas: encabezados semánticos, acciones accesibles, estado vacío, filtros y paginación; revisar variante móvil real.
5. Modales: foco inicial, cierre con teclado, retorno de foco y límites de alto/scroll.
6. Probar 320, 390, 768 y 1440 px, zoom 200%, es/en/ko, teclado y `prefers-reduced-motion`.
7. No afirmar que estos componentes son ViewComponents hasta comprobar sus clases Ruby/ERB.

## Evidencia pendiente
No se ha realizado prueba de navegador ni inventario exhaustivo de todos los componentes. Ampliar por módulo con referencias a vistas reales y capturas cuando estén disponibles.
