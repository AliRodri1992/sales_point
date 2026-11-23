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

## Inventario de patrones adicionales (inspección estática de feature/fixes)
| Patrón | Fuente inspeccionada | Contrato que debe preservarse |
|---|---|---|
| Filtros avanzados de Promociones | `app/views/admin/promotions/_filters.html.erb` | Ayuda contextual de sección, búsqueda, estado, `details`, filtros propios y botón primario |
| Acciones de Productos | `app/views/admin/products/_row_actions.html.erb` | `policy(Product).show?/update?/destroy?`, etiquetas accesibles, `delta_icon`, confirmación `swal-confirm` |
| Filtros de Listas de Precios | `app/views/admin/price_lists/_filters.html.erb` | Formulario GET, `delta-select`, moneda, producto, periodo, chips y parámetros de orden/paginación |
| Detalle de Producto | `app/views/admin/products/_show.html.erb` | `catalog-header`, `catalog-summary`, `catalog-card`, autorización de edición; revisar duplicidad semántica |
| Formulario de Lista de Precios | `app/views/admin/price_lists/form.html.erb` | `catalog-field`, validaciones, moneda desde `Currency.active.order(:code)` al crear y solo lectura al editar |

### Criterios de reutilización y verificación
- Comparar los contratos HTML/ERB, permisos y traducciones antes de extraer componentes; no trasladar reglas de negocio por similitud visual.
- Diferenciar ayuda global, ayuda de sección y ayuda de campo mediante ubicación, nombre accesible y contexto.
- Comprobar estados normal, carga, vacío, error, deshabilitado, hover y foco; modales con teclado y retorno de foco.
- Verificar 320/390/768/1440 px, zoom 200 %, `prefers-reduced-motion` y locales es/en/ko.
- Este inventario no constituye auditoría visual ni inventario exhaustivo; no afirmar verificación de navegador sin evidencia.
