# Registro de calidad — Categorías (Delta POS)

- **Módulo y ruta principal:** Categorías — `/admin/categories`
- **Rutas y acciones propias:** `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`; respuestas HTML y Turbo Stream.
- **Fuera de alcance:** interior de Productos, Promociones, Inventario, roles globales y componentes compartidos; solo se auditan sus contratos visibles desde Categorías.
- **Contratos externos:** Productos y condiciones de Promociones referencian `category_id`; Noticed y Turbo notifican cambios; Pundit autoriza acciones; preferencias de paginación.
- **SHA auditado:** `0481ca54046b633aa5b84667455fd134ba3139a4` (rama `feature/fixes`, 2026-11-09).
- **SHA de aceptación:** PENDIENTE. **Responsable de las correcciones y revisor independiente:** POR ASIGNAR.
- **Estado:** **AUDITADO POR INSPECCIÓN ESTÁTICA; NO VERIFICADO EN EJECUCIÓN; NO CERRADO**.
- **Método:** AI Dev Suite — `impeccable-audit` + `ui-ux-pro-max` + `ponytail-engineering`; estándar `docs/quality/module-quality-standard.md`.
- **Última revisión:** 2026-11-09. Se revisó código disponible en GitHub y estados de CI del SHA auditado. No se cambiaron controladores, modelos, migraciones, vistas, JS ni specs.

## Mapa de alcance y cobertura

| Pantalla / acción | Archivos principales | Permisos | Evidencia existente |
|---|---|---|---|
| `GET /admin/categories` | `app/controllers/admin/categories_controller.rb`, `index.html.erb`, `_list.html.erb`, `categories_search_controller.js`, `table_page_size_controller.js` | `categories.access` + `categories.index` | `spec/requests/admin/categories_spec.rb`, `catalog_pagination_spec.rb` |
| `show/new/edit` y modal | `_show.html.erb`, `_panel.html.erb`, `_form.html.erb`, `modal_controller.js` | `categories.show/create/update` | requests básicos; sin flujo JS focalizado |
| `create/update` | controlador, `Category`, `create/update.turbo_stream.erb`, `CategoryNotification` | `categories.create/update` | requests positivos y algunos negativos |
| `destroy` | controlador, `destroy.turbo_stream.erb`, SweetAlert | `categories.destroy` | request de soft delete y notificación; faltan dependencias activas |
| Validación/datos | `app/models/category.rb`, `db/schema.rb`, `CategoryPolicy`, `CatalogAuthorization` | Pundit | `spec/models/category_spec.rb`, `spec/policies/category_policy_spec.rb`, `granular_catalog_permissions_spec.rb` |
| Idiomas | `config/locales/es.yml`, `en.yml`, `ko.yml` | según pantalla | claves `admin.categories` presentes en los tres archivos |

## Registro único de hallazgos

IDs permanentes de esta primera auditoría. **Confirmado por código** significa que la condición indicada se observa en el código, **NO** que se haya reproducido en un navegador o en una ejecución de RSpec. Todos los estados son **ABIERTO**, salvo indicación contraria.

### CATEGORIES-001 · P1 · PROPIO + INTEGRACIÓN · Modelo global sin aislamiento por organización
- **Evidencia:** `db/schema.rb` (`categories` no tiene `organization_id`); `app/models/category.rb`; `CategoriesController#index/set_category/create/update/destroy` usan `Category` sin alcance tenant; `CategoryPolicy::Scope#resolve` devuelve `scope.all`. `Product` sí pertenece a `Organization` y contiene `category_id`.
- **Confirmado por código:** todos los usuarios con permiso de Categorías usan el mismo espacio de registros. **Pendiente de verificar:** una reproducción con dos organizaciones y usuarios de permisos distintos, y la decisión funcional de si el catálogo debe ser global.
- **Riesgo:** una categoría modificada o retirada por un negocio puede afectar clasificaciones compartidas por otro si el catálogo está pensado como dato de cada empresa. El subtítulo de la pantalla habla de categorías «de tu negocio».
- **Corrección requerida:** definir explícitamente titularidad. Si las categorías son de negocio, añadir relación/índices/alcance por organización, migración controlada de datos y reglas de asignación a Productos. Si deben ser globales, convertirlas en un catálogo administrado centralmente y impedir mutaciones intertenant de operadores de negocio.
- **Regresión:** dos organizaciones con categoría homónima, index/show/create/update/destroy cruzados, y relación de producto a categoría del tenant correcto.

### CATEGORIES-002 · P1 · PROPIO + INTEGRACIÓN · Borrado lógico permite referencias activas
- **Evidencia:** `CategoriesController#destroy` ejecuta `@category.update!(deleted_at: Time.current)` sin consultar dependencias; `Product#belongs_to :category` y `PromotionCondition#belongs_to :category` referencian el registro; `ApplicationRecord` utiliza `acts_as_paranoid`.
- **Confirmado por código:** no hay bloqueo de eliminación por productos ni condiciones de promociones asociadas. **Pendiente de verificar:** efectos concretos en pantallas operativas.
- **Riesgo:** la clave foránea sigue apuntando a la fila conservada, pero el acceso normal a la asociación puede ocultar la categoría retirada y dejar clasificación o condición comercial sin etiqueta accesible.
- **Corrección requerida:** impedir retirar una categoría en uso y mostrar explicación/alternativa «Inactivar», o definir explícitamente una política integral de conservación histórica. No ampliar la auditoría al interior de Productos o Promociones.
- **Regresión:** borrar categoría sin referencias, con producto activo, con promoción dependiente, asociaciones históricas, repetición y permisos.

### CATEGORIES-003 · P2 · PROPIO · Campo Descripción inaccesible
- **Evidencia:** `Category` valida `description` (máximo 500); columna en `db/schema.rb` y claves `form.description` en `es/en/ko.yml`. Sin embargo, `category_params` permite solo `name/code/status` y `_form.html.erb` / `_show.html.erb` no muestran descripción.
- **Confirmado por código:** imposible crear/editar/ver la descripción desde este CRUD.
- **Corrección:** integrar textarea opcional, máximo 500, validación bajo campo, vista detalle y strong parameters.
- **Regresión:** guardar, mostrar, editar, conservar al fallar otro campo y rechazar descripción demasiado larga.

### CATEGORIES-004 · P2 · PROPIO · Accesibilidad y visualización de validaciones incompletas
- **Evidencia:** `_form.html.erb` usa `form_state_classes` y `error_message_for`, pero etiquetas `code/name` carecen de `required_field_label` y campos carecen de `aria-invalid`, `aria-describedby` hacia sus errores y pistas. `FormValidationHelper` ya ofrece utilidades compatibles.
- **Confirmado por código:** asteriscos rojos y asociación programática de errores no implementados.
- **Corrección:** asteriscos a los campos requeridos, IDs de ayuda, atributos ARIA y errores individuales `nombreCampo mensajeValidación`, sin resumen duplicado ni depender de `required` HTML5.
- **Regresión:** 422 con nombre/código vacíos o inválidos, foco, errores visibles y asociados, datos conservados, es/en/ko.

### CATEGORIES-005 · P2 · PROPIO · Selects nativos frente al estándar visual
- **Evidencia:** `_form.html.erb` (estatus), `index.html.erb` (filtro estatus) y `_list.html.erb` (filas por página) usan `form.select`/`select_tag` sin componente visual propio.
- **Confirmado por código:** no siguen el dropdown Delta POS sin radios internos definido en el estándar.
- **Corrección:** adaptar al componente dropdown compartido preservando teclado, filtros, guardado de preferencia y errores ARIA.
- **Regresión:** abrir/cerrar/opciones/teclado/foco, filtros y persistencia del tamaño de tabla; móvil a 320/390 px.

### CATEGORIES-006 · P2 · PROPIO · Estado vacío confunde búsqueda sin resultados con catálogo vacío
- **Evidencia:** `_list.html.erb` muestra «Aún no hay categorías» y «Crea tu primera categoría» cuando `categories.any?` es falso, incluso si los filtros dejan cero filas sobre un catálogo que sí contiene registros.
- **Confirmado por código:** misma copia para dos estados funcionalmente distintos.
- **Corrección:** diferenciar sin registros de sin coincidencias; botón para limpiar filtros y CTA de creación solo con autorización.
- **Regresión:** catálogo vacío y catálogo con resultados filtrados a cero, con/sin `create?`.

### CATEGORIES-007 · P2 · INTEGRACIÓN (UI compartida) · Control de foco de la modal incompleto
- **Evidencia:** `modal_controller.js` coloca foco inicial, pero no implementa ciclo de Tab dentro del diálogo ni restaura foco al disparador al cerrar; `_panel.html.erb` y `_show.html.erb` declaran `role=dialog`, `aria-modal=true`.
- **Confirmado por código:** faltan esas rutinas; **pendiente de verificar:** comportamiento con lector de pantalla, Escape, fondo y navegador real.
- **Corrección:** solución mínima en componente modal compartido, justificada como contrato de UI usado aquí; no rediseñar otras modales.
- **Regresión:** apertura, Tab/Shift+Tab, Escape, retorno al botón disparador, cambios Ver→Editar y 422.

### CATEGORIES-008 · P2 · PROPIO · Unicidad frente a categorías retiradas
- **Evidencia:** índice único parcial `index_categories_on_code WHERE deleted_at IS NULL` en `db/schema.rb`, mientras `Category` usa `validates :code, uniqueness: true` sin condición explícita.
- **Hipótesis por verificar:** el validador puede rechazar reutilizar el código de una categoría eliminada aunque el índice de BD permita registros activos con ese código; podría haber una interacción específica con Paranoia.
- **Corrección:** confirmar la regla de negocio y alinear validador e índice sin pérdida de integridad.
- **Regresión:** retirada + alta con el mismo código, intento duplicado concurrente, diferencia por mayúsculas y recuperación si se habilita.

### CATEGORIES-009 · P2 · PROPIO · Integridad de base de datos incompleta
- **Evidencia:** la tabla `categories` permite `NULL` en `name`, `code`, `status`, y no tiene CHECK para `status`; las restricciones existen en modelo, no en BD.
- **Confirmado por esquema:** una escritura que evite validaciones ORM podría dejar categorías inválidas.
- **Corrección:** tras limpieza de datos, `NOT NULL` apropiados y CHECK para valores admitidos; migración reversible y `db:migrate` desde cero.
- **Regresión:** modelo y constraints de PostgreSQL para null, estado incorrecto y duplicados.

### CATEGORIES-010 · P2 · PROPIO · Cobertura funcional y de navegador insuficiente
- **Evidencia:** `spec/requests/admin/categories_spec.rb` cubre operaciones principales, filtros, notificaciones y soft delete; `spec/requests/admin/granular_catalog_permissions_spec.rb` cubre permisos. No se identificó un escenario JS específico de Categorías en `spec/features`; tampoco casos de los riesgos CATEGORIES-001/002 ni ARIA/modal/422 de cada campo.
- **Confirmado por inventario de pruebas:** falta evidencia de regresión específica para flujos críticos de categorías.
- **Corrección:** tests negativos por acción y 422, multiempresa, borrado con referencias, concurrencia, filtros con resultados vacíos, modal y viewport móvil.
- **Regresión:** ejecutar nuevos specs, asegurar que fallen antes de arreglos relevantes y pasen después.

### CATEGORIES-011 · P3 · PROPIO · Búsquedas con comodines sin escapar
- **Evidencia:** `CategoriesController#filter_scope` usa parámetro enlazado `ILIKE` con `%#{params[:search]}%`, sin escapar `%` ni `_`.
- **Confirmado por código:** no es interpolación SQL insegura (el valor está parametrizado), pero entradas como `%` y `_` actúan como comodines en vez de texto literal.
- **Corrección:** `ActiveRecord::Base.sanitize_sql_like`, limitar longitud útil y considerar índices trigram solo si volumen/EXPLAIN lo justifican.
- **Regresión:** búsquedas literales con %, _, acentos y espacios; no romper filtros y orden.

### CATEGORIES-012 · P3 · PROPIO · Skeleton de tabla no corresponde a columnas reales
- **Evidencia:** `index.html.erb` renderiza `Ui::SkeletonComponent` con `columns: 5`; `_list.html.erb` presenta cuatro columnas (nombre, código, estado, acciones).
- **Confirmado por código.** **Corrección:** igualar estructura del skeleton a cuatro columnas; verificar ausencia de salto visual.
- **Regresión:** carga y transición Turbo a 320/390/768/1440 px.

### CATEGORIES-013 · P2 · PROPIO · Rutas directas de modal con permisos parciales
- **Evidencia:** `new.html.erb` y `edit.html.erb` solo envuelven `_panel` en `turbo_frame_tag "category_modal"`, mientras `admin_dashboard.html.erb` también incluye un frame global `category_modal`. `CatalogNavigation` puede redirigir un usuario con permiso de alta pero sin permiso de listado hacia `new_admin_category_path`.
- **Hipótesis por verificar:** al visitar directamente `new/edit/show`, puede haber dos IDs de frame y presentación fuera de la modal, especialmente en un perfil sin `index?`.
- **Corrección:** garantizar ruta independiente renderizable o salida contextual sin IDs duplicados.
- **Regresión:** acceso directo, volver/recargar, permiso solo crear/editar/ver, navegación desde listado y 422.

## Elementos favorables verificados en código

- Acceso autenticado y autorización Pundit con permisos granulares por operación; existen request specs de denegación.
- Soft delete respaldado por `acts_as_paranoid` y un índice único parcial para códigos activos.
- Consultas ordenadas con lista blanca de columnas y direcciones; búsqueda parametrizada, no concatenada en SQL.
- Turbo Stream y SweetAlert para retroalimentación; notificaciones Noticed y preferencia por tabla.
- Claves `admin.categories` para las etiquetas visibles presentes en `es.yml`, `en.yml` y `ko.yml`; no se identificó por revisión textual una clave faltante de este grupo.
- La tabla tiene etiquetas accesibles en sus acciones de icono; pendiente prueba real con teclado y lector de pantalla.

## Verificaciones y resultados reales

| Fecha | SHA | Herramienta / comprobación | Resultado | Evidencia / límite |
|---|---|---|---|---|
| 2026-11-09 | `0481ca54` | Inspección estática de GitHub + skills AI Dev Suite | **EJECUTADA** | Código citado arriba; no acredita reproducción de interfaz |
| 2026-11-09 | `0481ca54` | `RSpec` global, GitHub Actions | **FALLÓ** | [CI #42615013668](https://github.com/AliRodri1992/sales_point/actions/runs/42615013668); no se atribuye a Categorías sin revisar sus fallas |
| 2026-11-09 | `0481ca54` | `RuboCop` global, GitHub Actions | **FALLÓ** | Misma ejecución; no se atribuye a Categorías sin revisar sus fallas |
| 2026-11-09 | `0481ca54` | `Security scans` | **PASÓ** | Misma ejecución |
| 2026-11-09 | `0481ca54` | `Fresh migrations and seed data` | **PASÓ** | Misma ejecución |
| 2026-11-09 | `0481ca54` | `Rails I18n and YAML audit` | **PASÓ** | Misma ejecución |
| 2026-11-09 | `0481ca54` | RSpec focalizado de categorías en entorno local | **NO EJECUTADO** | No hay proceso Rails/Docker local conectado a esta sesión |
| 2026-11-09 | `0481ca54` | Navegador del módulo protegido | **NO EJECUTADO** | La pestaña local disponible estaba en `http://localhost:3000/` sin sesión de administración; no hubo interacción con rutas protegidas |
| 2026-11-09 | `0481ca54` | Verificación de teclado, WCAG, responsive y lector de pantalla | **NO EJECUTADO** | Requiere navegador autenticado e inspección real |

## Secuencia recomendada de adecuación

1. **P1:** cerrar decisión sobre aislamiento empresarial de Categorías (CATEGORIES-001) y evitar retirada de categorías con referencias activas (CATEGORIES-002); escribir regresiones antes de migraciones/desarrollo.
2. **P2 funcional:** descripción, coherencia de unicidad y constraints, accesibilidad de formularios y rutas directas (003, 004, 008, 009, 013).
3. **P2 visual:** dropdowns, vacíos y modal accesible (005, 006, 007), con pruebas reales de 320, 390, 768 y 1440 px.
4. **Cobertura y pulido:** E2E específico, comodines, skeleton (010–012).
5. **Verificación:** `bash bin/overcommit-rspec spec/requests/admin/categories_spec.rb spec/models/category_spec.rb spec/policies/category_policy_spec.rb spec/requests/admin/granular_catalog_permissions_spec.rb` y nuevos specs; RSpec global, RuboCop, Brakeman, I18n/YAML, migraciones limpias, navegador y CI verde del SHA final. No fusionar con checks fallidos.

## Checklist de cierre

- [x] Alcance, SHA inicial, rutas, componentes, modelo, permisos y contratos identificados.
- [x] Hallazgos de código registrados con IDs estables, distinción confirmado/hipótesis y dueño.
- [x] Estado de las comprobaciones GitHub Actions consultado para SHA auditado.
- [ ] Evidencia de los escenarios P1 con dos organizaciones y asociaciones activas.
- [ ] Formulario y modal accesibles, validaciones por campo verificadas.
- [ ] Estados carga, vacío, 401/403/404/422 y errores de red probados.
- [ ] UI real desktop/móvil, contraste, teclado, zoom 200 %, lector de pantalla y es/en/ko.
- [ ] Regresiones nuevas y specs focalizados ejecutados en SHA final.
- [ ] RuboCop, RSpec, Security, I18n, migraciones y CI global verdes en SHA de aceptación.
- [ ] Sin P1 abiertos, P2 corregidos o aceptados formalmente, revisión independiente.

## Dictamen

- **P0 confirmados:** ninguno por inspección estática; no equivale a una garantía de ausencia.
- **P1 abiertos:** CATEGORIES-001 y CATEGORIES-002 (ambos necesitan prueba de integración).
- **P2 abiertos:** CATEGORIES-003 a CATEGORIES-010 y CATEGORIES-013.
- **P3 abiertos:** CATEGORIES-011 y CATEGORIES-012.
- **Estado final:** **AUDITADO ESTÁTICAMENTE / CORRECCIONES PENDIENTES / NO VERIFICADO / NO CERRADO**.
- **Revisor y fecha de aceptación:** PENDIENTES.

[Estándar modular](../module-quality-standard.md) · [Plantilla](../module-audit-template.md). Los IDs deben mantenerse en todas las reauditorías; no se da por cerrado ningún hallazgo solo por existir un commit.
