# Registro de calidad — Categorías (Delta POS)

- **Módulo y ruta principal:** Categorías — `/admin/categories`
- **Rutas y acciones propias:** `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`; respuestas HTML y Turbo Stream.
- **Fuera de alcance:** interior de Productos, Promociones, Inventario, roles globales y componentes compartidos; solo se auditan sus contratos visibles desde Categorías.
- **Contratos externos:** Productos y condiciones de Promociones referencian `category_id`; Noticed y Turbo notifican cambios; Pundit autoriza acciones; preferencias de paginación.
- **SHA auditado:** `0481ca54046b633aa5b84667455fd134ba3139a4` (rama `feature/fixes`, 2026-11-09).
- **SHA de aceptación:** PENDIENTE. **Responsable de las correcciones y revisor independiente:** POR ASIGNAR.
- **Estado inicial de auditoría:** **AUDITADO POR INSPECCIÓN ESTÁTICA; NO VERIFICADO EN EJECUCIÓN; NO CERRADO**. **Estado actual:** implementado y verificado en CI focalizado; cierre global aún pendiente.
- **Método:** AI Dev Suite — `impeccable-audit` + `ui-ux-pro-max` + `ponytail-engineering`; estándar `docs/quality/module-quality-standard.md`.
- **Última revisión:** 2026-11-09. Se revisó código disponible en GitHub y estados de CI del SHA auditado. Esa fue la revisión inicial; las adecuaciones posteriores sí modificaron código y pruebas, como se documenta al final.

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

## Implementación incremental 2026-11-09

- Se publicaron controles de baja de categorías en uso (Productos/Promociones), validación de índice de códigos retirados, constraints preventivos para nuevos datos, captura y visualización de descripción, búsqueda literal y respuestas de conflicto.
- Se ajustaron formularios, selectores, etiquetas ARIA, rutas independientes, estados vacíos, skeleton, foco de modales y textos `es/en/ko`.
- Se añadieron regresiones de solicitud y modelo en `spec/requests/admin/categories_spec.rb` y `spec/models/category_spec.rb`.
- **Estado de los hallazgos:** CATEGORIES-002 a CATEGORIES-009 y 011–013: **IMPLEMENTADO SIN VERIFICAR** (excepto CATEGORIES-009: constraints `NOT VALID`, pendientes de limpieza y validación para registros antiguos). CATEGORIES-010: **EN CORRECCIÓN** (falta escenario de navegador y verificación). CATEGORIES-001: **IMPLEMENTADO SIN VERIFICAR**; migración `20261110043000_scope_categories_to_organizations.rb` crea copias por organización, remapea referencias y conserva filas globales retiradas. No se afirma resuelto antes de migraciones/CI reales.
- **Evidencia:** commits en `feature/fixes`, pendientes de RSpec/RuboCop/CI completos para SHA de aceptación. Se mantiene **NO CERRADO**.

### Segunda etapa — alcance multiorganización

- Categorías nuevas asignadas a `current_organization` desde el controlador; consultas, detalles, cambios y notificaciones restringidos a esa organización.
- `CategoryPolicy::Scope`, la selección de categorías en Productos y las condiciones de Promociones se ajustaron al mismo contrato. Referencias cruzadas con organización distinta se rechazan en validaciones de modelos.
- Migración gradual reversible **a nivel de transacción**; el `down` es deliberadamente irreversible porque los datos de dos organizaciones pueden divergir después de la copia. No se elimina ninguna categoría histórica; se marca como retirada después de reasignar las asociaciones.
- **Bloqueo de aceptación:** revisar la ejecución real del backfill, tiempos y conteos antes/después, validación de constraints legados y pruebas de aislamiento multiorganización.

## Verificación focalizada real — 2026-11-09

**SHA de código verificado:** `e553a5f976e22724c03e365b62681ae63ae5cd00`.  
**GitHub Actions:** [Categories CI #42622839776](https://github.com/AliRodri1992/sales_point/actions/runs/42622839776) — **SUCCESS**.

| Comprobación | Resultado real | Evidencia |
|---|---|---|
| RuboCop focalizado | **PASÓ**: 13 archivos, 0 ofensas | Job `129179055065` |
| `db:drop db:create db:migrate` sobre PostgreSQL 16 de pruebas | **PASÓ** | Job `129179055372`; base limpia |
| RSpec focalizado de categorías, permisos, aislamiento y paginación | **PASÓ** | En conjunto, 93 ejemplos, 0 fallos |
| Capybara/Chrome: modal, validaciones y descripción | **PASÓ** | `spec/features/categories_quality_browser_spec.rb` incluido en esos 93 ejemplos |

### Dictamen actualizado

- **Implementado y verificado en CI focalizado:** CATEGORIES-002 a CATEGORIES-008, CATEGORIES-011, CATEGORIES-012 y CATEGORIES-013 respecto de los escenarios automatizados correspondientes. Los cambios de Categorías quedaron comprobados en navegador Chrome del runner y no presentan fallos en los specs focalizados del SHA indicado.
- **CATEGORIES-001 (aislamiento):** controles y regresiones de dos organizaciones verificadas en tests automatizados; la **conversión de datos históricos con organizaciones reales** todavía requiere prueba con un clon/respaldo de datos existentes. Esta evidencia no la proporciona una base de pruebas creada desde cero.
- **CATEGORIES-009 (constraints):** comprobada instalación de esquema de prueba limpio; se mantienen constraints `NOT VALID` para no bloquear registros históricos sin auditar. Falta validación sobre datos de producción/de desarrollo existentes.
- **CATEGORIES-010 (cobertura):** suite focalizada y escenario Chrome verificados. No se realizó inspección manual independiente de viewport 320/390/768/1440, zoom 200 %, todos los lectores de pantalla ni todos los estados 401/422 en navegador.
- **Bloqueos de cierre:** no hay evidencia de **CI global verde del SHA de aceptación**, ni revisión independiente completa del UI; el run global del SHA `e553a5f` fue cancelado por nuevas publicaciones concurrentes en `feature/fixes`. Se mantiene **NO CERRADO**, sin fusionar ramas.
- **Atención a commits posteriores:** cualquier cambio que modifique contratos o estilos debe revalidarse en el nuevo SHA. Actualizar aquí los resultados de la ejecución específica correspondiente.


## Reauditoría visual de Categorías — 2026-11-09

Metodología: AI Dev Suite (impeccable-audit, ui-ux-pro-max y ponytail-engineering), estándar visual Delta POS. Inspección de /admin/categories en feature/fixes y de su CI. No se usó Figma.

### Nuevos hallazgos con IDs permanentes

| ID | Prioridad | Evidencia inicial | Adecuación y verificación |
| --- | --- | --- | --- |
| CATEGORIES-014 | P2 | Encabezado agrupaba CTA, búsqueda y selectores en un espacio reducido | Encabezado independiente, filtro compacto, opciones avanzadas plegables; IMPLEMENTADO, sin verificación visual independiente |
| CATEGORIES-015 | P2 | No existían etiquetas visibles para cada filtro activo | Chips removibles de búsqueda, estado y orden; IMPLEMENTADO, pendiente prueba manual |
| CATEGORIES-016 | P2 | Únicamente tabla con scroll horizontal en móvil | Tarjetas móviles con identidad, descripción, estado y acciones; IMPLEMENTADO, sin viewport real verificado |
| CATEGORIES-017 | P2 | Descripción ausente del listado aunque disponible en modelo y formulario | Columna Descripción y skeleton de cinco columnas; IMPLEMENTADO, pendiente comprobación visual |
| CATEGORIES-018 | P2 | Doble acción Nueva categoría tras el primer rediseño en catálogo vacío | Reproducido en Chrome/Capybara CI, se elimina el CTA duplicado en el estado vacío; CORREGIDO, pendiente CI actualizado |
| CATEGORIES-019 | P2 | Cierre de modal pequeño y espaciado irregular en consulta/edición | Botón cerrar de 44 px, cabecera/pie coherentes y límite de scroll de la modal; IMPLEMENTADO, pendiente validación de foco y lectores |

### Evidencia de ejecución y alcance

- Ejecución Categories CI #42758883558 sobre 4d2eaf3c1b0bf24d1152d98c7677d964a1dbaa9a: RuboCop focalizado aprobó. RSpec ejecutó 94 ejemplos y reportó cuatro fallos: uno de Categorías por el doble CTA y tres de permisos de Clientes.
- Los tres casos de Clientes (consultar, actualizar y eliminar) recibieron 404 en la suite compartida granular_catalog_permissions_spec.rb. Se clasifican como EXTERNOS, sin cambiar código ni ocultar tests de Clientes.
- Las mejoras visuales no modifican el aislamiento de organizaciones, autorización Pundit, reglas de borrado en uso, esquemas ni migraciones.
- Nuevos escenarios request/Chrome cubren filtros, descripciones y tarjetas; se deben ejecutar en el SHA de aceptación.
- Se mantienen pendientes la prueba de migración de datos históricos, validación de restricciones NOT VALID, CI global verde y revisión visual manual en 320, 390, 768 y 1440 px, zoom 200 %, teclado, es/en/ko y lector de pantalla.
- Estado del módulo: IMPLEMENTADO Y EN REAUDITORÍA; NO CERRADO.

## Reauditoría de diseño y navegación — segunda pasada (2026-11-09)

**Método:** AI Dev Suite: impeccable-audit (jerarquía/estados), ui-ux-pro-max (sistema de componentes), ponytail-engineering (cambios acotados). Alcance: /admin/categories y sus contratos visibles; rama feature/fixes. No se utilizó Figma ni se modificaron datos o migraciones.

| ID | Prioridad | Hallazgo confirmado por código | Corrección aplicada | Estado |
|---|---|---|---|---|
| CATEGORIES-020 | P2 | Ordenar nombre descendente dejaba el encabezado ordenado sin chip de filtro activo | Chip eliminable con dirección ascendente/descendente y conservación de los demás parámetros | Implementado; por verificar en nuevo CI |
| CATEGORIES-021 | P2 | Los encabezados de tabla actualizaban resultados por Turbo Frame pero no los controles avanzados fuera del frame | Sincronización de selectores de orden/dirección tras turbo:frame-load; prueba Chrome añadida | Implementado; por verificar en nuevo CI |
| CATEGORIES-022 | P2 | CTA en color --brand podía presentar contraste insuficiente con texto blanco; targets de acciones solo 40 px | Fondo --brand-on-white del sistema, targets de 44 px, foco visible, ajustes suaves de jerarquía y modales | Implementado; por revisar contraste de temas en navegador |
| CATEGORIES-023 | P3 | Consultar dependía de identificar el icono de ojo; nombre sin enlace | El nombre también abre el detalle en modal, solo con permiso show?, en escritorio y móvil | Implementado; pruebas de request añadidas |
| CATEGORIES-024 | P2 | Estado inválido vía URL producía cero coincidencias sin una etiqueta que explicara el filtro | El controlador ignora estados fuera de los enumerados, como se hace con columnas de orden; nueva prueba | Implementado; CI pendiente |

### Comprobaciones y riesgos

- Commit de implementación: 9c59dc8e909f29dc7aab3ad0a0d6e95b18fd2fe7. Nueve archivos alterados en un commit de refuerzo visual, estado de filtros, accesibilidad y pruebas.
- Categories CI #42761545785: RuboCop encontró dos detalles de líneas vacías en las pruebas nuevas; se ajustaron en este commit. El job funcional todavía estaba en ejecución cuando se registró esta nota; consultar el resultado por SHA, no asumir éxito.
- La ejecución anterior #42759712208 incluyó 98 ejemplos, con cuatro fallos fuera de Categorías: tres de Clientes y uno de paginación de Productos. Son contratos de otros módulos y no se borran de la suite para ocultar fallos.
- SIGUE PENDIENTE: inspección renderizada 320/390/768/1440 y zoom 200 %, navegación real por teclado, lector de pantalla, es/en/ko, contraste de todos los temas, backfill de categorías históricas y validación de constraints NOT VALID.
- Cierre de Categorías: NO CERRADO hasta verificar el SHA de aceptación con CI global y revisión visual independiente.

### CI y regresión de la segunda pasada — actualización de verificación

- Categories CI #42761881557 ejecutó **102 ejemplos, 6 fallos**: dos nuevos propios (CATEGORIES-021 por sincronización de orden en Chrome y CATEGORIES-024 por fixture vacío en request spec) y cuatro externos (3 Clientes, 1 paginación de Productos). RuboCop pasó: 13 archivos, 0 ofensas.
- Las dos regresiones propias se atendieron: CATEGORIES-021 también observa cambios de DOM en el Turbo Frame (incluye renders Turbo Stream) y espera de forma explícita la selección actualizada en Chrome; CATEGORIES-024 prepara una categoría del tenant antes de comprobar el filtro desconocido.
- **Estado:** correcciones publicadas, a la espera de nueva ejecución. No atribuir éxitos que correspondan a un SHA anterior. No cerrar sin verificar CI focalizado y global, y completar revisión visual real.

### Verificación de las correcciones CATEGORIES-020 a CATEGORIES-024

**SHA de código verificado:** a821593f3a43751fccce8ea1c8ccef0856cbd2b2. **Ejecución:** Categories CI #42762227534 (2026-11-09 hora local; registros UTC 2026-11-10).

| Comprobación | Resultado observado |
| --- | --- |
| RuboCop focalizado (13 archivos) | SUCCESS, cero ofensas |
| Preparación de PostgreSQL y migraciones de prueba | SUCCESS, condición previa al RSpec |
| RSpec y Chrome del workflow focalizado | 102 ejemplos, 98 aprobados, 4 fallos externos |
| Flujos de Categorías (alta, descripción, aislamiento, filtros, orden, navegación, Chrome) | Sin fallos en el reporte de ejecución |
| Contratos compartidos de Clientes | 3 fallos en permisos show/update/delete, HTTP 404; EXTERNO |
| Contrato compartido de Productos | 1 fallo en etiquetas de paginación; EXTERNO |

En particular, los fallos propios de CATEGORIES-021 (sincronización de orden) y CATEGORIES-024 (fixture de estado inválido) detectados en #42761881557 ya no aparecen en #42762227534. Se conservaron todas las pruebas originales y añadidas.

El CI global #42762227403 ya confirma I18n/YAML y Security scans satisfactorios; RuboCop global aún falla y los demás jobs estaban ejecutándose al registrar la evidencia. El contrato de calidad exige CI global completamente verde para el SHA final.

**Dictamen actualizado:** regresiones automatizadas propias del rediseño VERIFICADAS en CI focalizado; problemas externos de Clientes y Productos abiertos; revisión manual de UI (320/390/768/1440, 200 % zoom, teclado, lector de pantalla y temas) y migración/backfill legados pendientes. Categorías NO CERRADO; no fusionar hasta superar las puertas de aceptación.

## Simplificación de filtros — 2026-11-09 (CATEGORIES-025)

- **CATEGORIES-025 · P3 · UX (confirmado):** el apartado denominado «Filtros avanzados» solo contenía **ordenar por** y **dirección**, sin criterios adicionales de filtrado; añadía complejidad visual injustificada.
- **Adecuación:** eliminado el bloque desplegable y sus estilos exclusivos en `/admin/categories`. Se conservan la búsqueda automática y el filtro principal por estado; el ordenamiento continúa disponible mediante los encabezados de la tabla.
- **Continuidad funcional:** se conservan `sort` y `direction` como entradas ocultas del formulario, sincronizadas al ordenar desde un encabezado con Turbo Frame; evita perder el orden al buscar o cambiar el estado. Las etiquetas removibles de filtros/orden y los parámetros de URL continúan funcionando.
- **Regresiones:** request spec confirma ausencia del panel avanzado y presencia de campos ocultos; Chrome comprueba orden descendente y sincronización sin el panel.
- **Estado:** IMPLEMENTADO, pendiente CI del nuevo SHA y revisión visual manual. No se modificaron reglas de negocio ni migraciones. Este ajuste no cierra las incidencias históricas ajenas de Clientes y Productos.

## Ajuste de ancho y densidad visual de modal — 2026-11-10 (CATEGORIES-026)

- **CATEGORIES-026 · P3 · UX:** la modal de crear/editar Categorías estaba limitada a 560 px y distribuía código, nombre, descripción y estatus en una sola columna, aumentando innecesariamente su altura.
- **Adecuación aplicada:** ancho máximo moderado de **680 px**; código y nombre en dos columnas a partir de 640 px; descripción a todo el ancho; estatus mantiene espacio propio en edición. Se conserva scroll vertical cuando la ventana es baja, botones y validaciones individuales.
- **Responsive:** a menos de 640 px el formulario vuelve a una columna. El detalle de categoría comparte la nueva anchura sin alterar el layout de lectura.
- **Regresión agregada:** test Chrome comprueba ancho, alineación de los campos en escritorio y apilamiento sin desborde horizontal en 390 px. Pendiente ejecución del CI del nuevo SHA y revisión manual de zoom 200 %.
- **Alcance:** solo Categorías; sin cambios en migraciones, validaciones de modelo, roles ni localizaciones.


## Reauditoría integral — 2026-11-10 (sin cambios funcionales)

**SHA inicial y auditado:** `9ac9c227f729bbcc8b045ee8604775d083e41511` (`feature/fixes`). **Método:** AI Dev Suite como procedimientos de `impeccable-audit`, `ui-ux-pro-max` y `ponytail-engineering` aplicados mediante inspección GitHub/CI (no se ejecutaron los CLIs externos). **Alcance propio:** `/admin/categories`, `CategoriesController`, `Admin::CategoryMutations`, `Category`, `CategoryPolicy`, vistas Turbo/ERB, CSS/Stimulus, traducciones y specs. Clientes y Productos se contabilizan solo en su contrato externo. No se usó Figma.

### Reapertura de hallazgos y evidencia

- **CATEGORIES-025 · P2 · REABIERTO (fallos en regresiones, no demostrado como rotura visual):** se retiró el acordeón de orden/dirección y se conservaron entradas ocultas. El run [Categories CI #42809388428](https://github.com/AliRodri1992/sales_point/actions/runs/42809388428) informa dos pruebas propias fallidas: `spec/requests/admin/categories_spec.rb:378` no encuentra `th a[href*="sort=name"]`, pero ese escenario no crea filas y la vista solo renderiza la tabla cuando `categories.any?`; `spec/features/categories_quality_browser_spec.rb:67` usa `have_field` para el `input type="hidden"` de dirección, cuya localización depende del selector de Capybara. **No afirmar que el orden se pierde para el usuario** sin inspección de DOM y prueba correcta. Responsable: Categorías. Regresión: preparar categoría del tenant, inspeccionar `input[type=hidden]` explícitamente y comprobar persistencia de orden al buscar/filtrar. Se mantienen los dos fallos abiertos hasta CI verde.
- **CATEGORIES-026 · P3 · VERIFICADO PARCIALMENTE:** las pruebas Chrome de modal a 1280 px/390 px, dos columnas en escritorio y apilado móvil aparecen entre los ejemplos aprobados de #42809388428. La modal `.categories-modal` tiene `max-width:680px` y altura limitada con scroll. Falta inspección manual 320/768/1440 px, zoom 200%, lector de pantalla y diferentes idiomas/temas.

### Nuevos hallazgos con ID permanente

| ID | Prioridad | Área y estado | Evidencia y comportamiento esperado | Responsable / regresión |
|---|---|---|---|---|
| CATEGORIES-027 | P2 | PROPIO · confirmado por código; reproducción pendiente | `Admin::CategoryMutations#category_saved` invoca `load_categories` con los parámetros de POST/PATCH/DELETE. Los enlaces de nueva/editar y el `button_to` de eliminar no transmiten búsqueda/estado/orden de la lista; `create/update/destroy.turbo_stream.erb` reemplazan `categories_list` mientras el formulario de filtros está fuera del frame. **Riesgo:** resultados y chips que ya no coinciden con el texto/estado del filtro hasta una recarga o broadcast. Se debe conservar el estado visible del listado de forma explícita. | Categorías; Chrome con búsqueda/estado activos + crear, editar, eliminar, comprobando inputs, chips y filas al terminar |
| CATEGORIES-028 | P2 | PROPIO · confirmado por código; reproducción pendiente | `CategoriesController#apply_sorting` aplica solo `scope.order(sort_column => sort_direction)`. `Category` permite nombres repetidos; paginar con `LIMIT/OFFSET` sobre valores de orden no únicos carece de desempate estable por ID. **Riesgo:** duplicados/omisiones entre páginas, especialmente al cambiar datos. | Categorías; ordenar varios registros homónimos por página pequeña y usar segundo criterio estable |
| CATEGORIES-029 | P2 | PROPIO · confirmado por estilos; contraste visual no medido | `categories_workspace.css` aplica verde esmeralda fijo a `.categories-avatar`, `.categories-status`, `.categories-filter-chip`, `.categories-empty-icon` y hovers, mientras el sistema dispone de colores de marca parametrizados por tema. **Riesgo:** el catálogo no adopta completamente temas distintos y sus contrastes pueden variar. | Categorías/identidad visual; comparar temas soportados y medir contraste, preferir tokens semánticos |
| CATEGORIES-030 | P2 | PROPIO · confirmado por vistas; pruebas asistivas pendientes | Los encabezados ordenables de `_list.html.erb` son enlaces `sort_link`, pero los `th` carecen de `aria-sort` para indicar a tecnologías asistivas la columna/dirección vigente. | Categorías; ARIA y teclado sobre orden asc/desc, con lector de pantalla y request spec |

### CI real del SHA auditado

- **Categories CI #42809388428:** RuboCop focalizado **SUCCESS**; RSpec + navegador Chrome **104 ejemplos, 6 fallos**: **2 propios** de pruebas de conservación del orden (`categories_spec.rb` y `categories_quality_browser_spec.rb`), **3 externos de permisos de Clientes** (404 en show/update/destroy), **1 externo de paginación de Productos** (etiquetas de página).
- **CI global #42809388942:** `RuboCop`, `Security scans` y `Rails I18n and YAML audit` **SUCCESS**; `RSpec` **FAILURE**, en job de rendimiento: `spec/performance/n_plus_one_scaling_spec.rb:51` (Clientes, esperaba consultas de teléfonos >=1 y obtuvo 0). `Fresh migrations and seed data` seguía en ejecución en la consulta realizada; no presumir su resultado.
- **Pruebas no realizadas en esta reauditoría:** navegador local autenticado en `/admin/categories` (las pestañas conectadas solo mostraban Idiomas en localhost), lectores de pantalla, zoom, auditoría de contraste por cada tema y migración/backfill sobre copia de datos históricos reales. No se ejecutaron RSpec/RuboCop en el Mac; los resultados proceden exclusivamente de Actions.

### Riesgos ya registrados, no duplicar

- **CATEGORIES-001 / 009:** falta evidencia sobre migración/aislamiento de datos históricos y validación completa de constraints legados `NOT VALID`; base de pruebas nueva no sustituye un clon de datos existentes.
- **CATEGORIES-010:** cobertura de flujos y errores; añadir regresiones enfocadas a los hallazgos 027–030, incluidas rutas directas, estados 422 y restauración de foco cuando corresponda.
- El CI global y el focalizado permanecen rojos, por lo que **no existe SHA de aceptación ni cierre**.

### Dictamen y secuencia de corrección

1. P2: corregir las dos pruebas del contrato de ordenación (CATEGORIES-025), verificar valor oculto y flujo real en Chrome, y reejecutar CI focalizado sin eliminar los escenarios externos.
2. P2: corregir conservación de filtros tras altas/ediciones/bajas (027), estabilizar la paginación (028), añadir accesibilidad de `aria-sort` (030) y revisar tokens/contraste de temas (029).
3. Validar Chrome con escenarios reales y locales es/en/ko, 320/390/768/1440 px, zoom 200%, teclado/foco, errores y estado vacío.
4. Revisar backfill y constraints sobre datos históricos; repetir RSpec, RuboCop, seguridad, I18n y migraciones; pedir revisión independiente y CI global verde antes de cualquier fusión.

**Estado:** REAUDITADO, HALLAZGOS ABIERTOS, NO CERRADO. Esta entrega registra solo auditoría/evidencia, sin cambios en código funcional, datos ni migraciones.

## Implementación de hallazgos CATEGORIES-025 y CATEGORIES-027 a 030 (2026-11-10)

- **CATEGORIES-025 / regresiones propias:** `categories_spec` ahora crea datos antes de buscar el enlace de ordenación; la prueba Chrome verifica el campo de dirección oculto mediante selector CSS explícito, sin confundirlo con un campo visible. **IMPLEMENTADO; CI del nuevo SHA pendiente**.
- **CATEGORIES-027 · filtros tras CRUD:** rutas y acciones de creación, edición, consulta y baja conservan el contexto de filtros del listado mediante query params. El controller Stimulus sincroniza los valores visibles al navegar o enviar un formulario, y usa `history.replaceState` tras refrescos Turbo Frame para que un broadcast no descarte los filtros de la URL. Los formularios preservan dichos parámetros en sus acciones. **IMPLEMENTADO; CI pendiente**.
- **CATEGORIES-028 · orden determinista:** `apply_sorting` introduce `id ASC` como desempate en cualquier columna seleccionada; regresión request para nombres repetidos y páginas múltiples. **IMPLEMENTADO; CI pendiente**.
- **CATEGORIES-029 · identidad de tema:** insignias decorativas, chips de filtros, controles hover e iconografía vacía utilizan `--brand-light` / `--brand-on-white`. El estado «activo» permanece verde por semántica, no por decoración. **IMPLEMENTADO; contraste visual por cada tema pendiente**.
- **CATEGORIES-030 · lector de pantalla:** los encabezados ordenables de Nombre/Código incorporan `aria-sort` únicamente cuando representan la columna activa; request spec nuevo para orden descendente. **IMPLEMENTADO; lector de pantalla físico pendiente**.
- **Cobertura nueva:** escenarios Chrome de búsqueda activa + alta; request con enlaces y formularios que retienen parámetros y persistencia de orden en paginación. Sin migraciones ni cambios de permisos.
- **Bloqueos de cierre externos:** RSpec global en Clientes (rendimiento de teléfonos), permisos granulares Clientes y paginación Productos siguen clasificados como EXTERNOS; se requieren correcciones independientes y CI global verde para cierre. Verificar migración histórica/constraints con una copia de datos reales antes de declarar CATEGORIES-001 / 009 cerrados.

### Verificación adicional de integridad por organización y CRUD (2026-11-10)

- Se adecuó el spec preexistente de `Category#in_use?` para crear producto y categoría en **la misma organización**, coherente con las reglas multitenant del modelo. Antes creaba organizaciones distintas y fallaba con `Category is invalid`; no se relajaron validaciones.
- Dos nuevos casos request comprueban conservación de filtros tras **actualización** y **baja** en Turbo Stream (el caso de creación ya existe).
- Se fortaleció el caso Chrome: espera el cierre de la modal y que la etiqueta de búsqueda siga visible después de crear un registro fuera del filtro.
- La ejecución focalizada del SHA `2ac8400730b4f89697163b824a1882fff06d0388` alcanzó 109 ejemplos, 7 fallos, ninguno en el nuevo flujo Chrome ni en tests request del rediseño. Tres fallos correspondían a una plantilla de Productos con error sintáctico, tres a permisos de Clientes y uno al test de modelo Categoria con fixture cross-tenant ahora corregido.
- **Estado:** corrección de fixture y pruebas adicionales implementadas, CI nuevo pendiente. Bloqueos externos no se ocultan ni se atribuyen al módulo.


### Evidencia focalizada de adecuaciones (2026-11-10)

- **Categories CI #42813087484**, SHA `7688ce658b90e23725d2b88159002c6ab52a59d4`: **111 ejemplos RSpec/Chrome, 6 fallos**, ninguno en Categorías. Los fallos fueron: **3 de Productos** por `ActionView::SyntaxErrorInTemplate` en `app/views/admin/products/_filters.html.erb:116` (parámetro `inputmode` sin cerrar), y **3 de permisos de Clientes** en show/update/destroy (404). Los nuevos tests de create/update/delete filtrados, orden estable, `aria-sort`, modelo con organización consistente y modal/búsqueda pasaron en esta ejecución.
- Ese run reportó una ofensa de RuboCop (`Layout/EmptyLines`) en un spec de Categorías, corregida en `43adcf79369178ab7b00570be67906c06d4b86ec`.
- **Categories CI #42813215996**, SHA `43adcf79369178ab7b00570be67906c06d4b86ec`: **RuboCop focalizado SUCCESS**. El job RSpec/Chrome estaba en ejecución durante esta actualización; verificar su conclusión por SHA.
- **CATEGORIES-025, 027, 028, 030:** cambios implementados y sin fallos propios en el run focalizado #42813087484. **CATEGORIES-029:** tokens actualizados, falta medición independiente de contraste en todos los temas. **CATEGORIES-026:** pruebas de Chrome en desktop/móvil ya incorporadas y pasaron.
- Los fallos externos son bloqueos de la **puerta de CI completa**, pero no se corrigen alterando módulos Clientes/Productos desde este expediente. Mantener responsables externos separados y los tests sin excluir.
- **CATEGORIES-001 / 009:** el CI de base limpia comprueba instalación pero no sustituye prueba de backfill y `VALIDATE CONSTRAINT` sobre copia de datos históricos. No ejecutar conversiones destructivas ni declarar «cerrado» sin evidencia.
- **Estado:** ADECUACIONES IMPLEMENTADAS, VERIFICACIÓN AUTOMATIZADA FOCALIZADA PARCIAL, CI GLOBAL / ACCESIBILIDAD MANUAL / DATOS LEGADOS PENDIENTES. No fusionar.


## Reauditoría independiente de cambios — 2026-11-10 (tercera pasada)

**SHA auditado:** `1fb86a4a9f2001a78c2a7c5269346f519e2017d6`, rama `feature/fixes`. **Herramientas:** inspección de código y GitHub Actions con procedimientos de AI Dev Suite (`impeccable-audit` y `ui-ux-pro-max`). No se ejecutó el CLI original de Impeccable ni se inspeccionó una pantalla local autenticada de Categorías. **Alcance:** controlador, modelo, permisos, modales, catálogo, paginación, Turbo/Stimulus, vistas móvil/escritorio, estilos y specs, más contratos de frontera con Clientes/Productos.

### Estado de hallazgos preexistentes

| Hallazgo | Resultado en el SHA auditado | Estado |
|---|---|---|
| CATEGORIES-025 | Desplegable avanzado retirado; orden mediante encabezados de tabla y campos ocultos. Su regresión request + Chrome aprobó en Categories CI #42814087630. | Verificado **automáticamente**; móvil bajo nueva observación 031 |
| CATEGORIES-026 | Modal de 680 px; pruebas Chrome confirman dos columnas a 1280 px y apilamiento a 390 px. | Verificado **automáticamente**; revisión manual 320/768/1440 px, zoom 200 %, foco, lector de pantalla pendientes |
| CATEGORIES-027 | Filtros transportados a URLs de alta/edición/baja y sincronización Stimulus; casos request y Chrome propios sin fallos en #42814087630. | Verificado **automáticamente** en escenarios cubiertos; nuevo riesgo 032 |
| CATEGORIES-028 | `CategoriesController#apply_sorting` aplica `id ASC` como desempate; spec con nombres repetidos y 2 páginas pasó. | Verificado automáticamente |
| CATEGORIES-029 | Colores decorativos reemplazados por `--brand-light` y `--brand-on-white`; estatus operativo permanece con verde semántico. | Implementado; pendiente contraste real en cada tema y modo accesible |
| CATEGORIES-030 | Encabezados de Nombre y Código emiten `aria-sort` al ordenar y la prueba request pasó. | Verificado automáticamente; lector de pantalla manual pendiente |
| CATEGORIES-001/009/010 | Falta comprobar migración histórica, constraints heredadas y ciertas rutas manuales de error/teclado. | Abiertos según registro previo; sin renumerarlos |

### Hallazgos nuevos

| ID | Prioridad | Confirmación | Evidencia, consecuencia y corrección requerida |
|---|---|---|---|
| **CATEGORIES-031** | **P2 UX / accesibilidad móvil** | **Confirmado por código; navegador móvil manual pendiente** | La vista a `max-width:1099px` oculta `.categories-desktop-table`, que contiene los únicos enlaces visibles para ordenar por Nombre/Código. Tras retirar `details.categories-advanced`, `categories-mobile-list` no proporciona un control propio para cambiar el orden. **Esperado:** conservar alguna opción compacta y accesible para ordenar desde móvil sin reinstalar un falso panel «avanzado». Responsable: Categorías. Regresión: Chrome a 390 y 768 px + teclado. |
| **CATEGORIES-032** | **P2 coherencia de filtros/paginación** | **Confirmado por flujo de código; falta reproducción Chrome** | `categories_search_controller.js#filteredUrl` modifica `search/status/sort/direction` pero preserva `page` de `window.location.href`; el `form_with` de búsqueda/estado no incluye `page`, así que al aplicar un filtro desde `?page=3` el servidor muestra la primera página, mientras `history.replaceState` puede dejar `page=3` en la barra. Una actualización por `broadcast_refresh_to` podría cargar de nuevo la página 3. **Esperado:** quitar `page` cuando cambia búsqueda/estado/orden o sincronizarlo con la página efectivamente renderizada, pero conservarlo en navegación de paginación explícita. Responsable: Categorías. Regresión: Chrome en página 3 -> buscar/filtrar -> URL/página 1 -> broadcast. |
| **CATEGORIES-033** | **P2 actualización entre sesiones con permisos granulares** | **Confirmado por código; caso multiusuario no ejecutado** | `Admin::CategoryMutations#category_saved` ejecuta `return if redirect_without_catalog_listing(@category, action)` **antes** de `broadcast_categories_update`. En un usuario autorizado a crear/editar/eliminar pero no a listar, la mutación puede guardarse y redirigir sin emitir el refresco para otras sesiones de su organización. **Esperado:** notificar los cambios guardados a espectadores autorizados independientemente del permiso `index?` del actor. Responsable: Categorías; spec de permisos granulares + expectativa de broadcast. |

### Ejecuciones y alcance de evidencia

- **Categories CI #42814087630:** SHA `41afb15dbcb4`, **RuboCop focalizado SUCCESS**; **111 ejemplos / 6 fallos**, **ninguno propio de Categorías**. Los seis fallos externos: 3 permisos granulares de **Clientes** (404 en consultar/actualizar/eliminar) y 3 **Productos** (2 paginación y 1 catálogo bajo permisos, con `ActionView::SyntaxErrorInTemplate` en `app/views/admin/products/_filters.html.erb:118`). Los escenarios propios de Categorías en ese run finalizaron sin errores. No atribuir esos fallos al módulo ni excluir los tests.
- **CI global #42814668387** del SHA `1fb86a4a9f2001a78c2a7c5269346f519e2017d6`: **RuboCop, Security scans, Rails I18n/YAML y Fresh migrations and seed data SUCCESS**. Al registrar esta auditoría, **RSpec seguía en ejecución**; el resultado del run no es todavía verde.
- **Limitaciones:** sin Mac/localhost autenticado, sin prueba visual manual 320/390/768/1440, zoom 200 %, todos los temas, `es/en/ko`, lector de pantalla o restauración de foco en errores; sin ensayo del backfill en copia histórica real ni `VALIDATE CONSTRAINT` legacy. Los resultados CI verifican solo sus escenarios, no todas las combinaciones.

### Dictamen

**REAUDITADO · CÓDIGO PREVIO VERIFICADO AUTOMÁTICAMENTE EN SU ALCANCE · 3 NUEVOS P2 ABIERTOS · NO CERRADO.** Se recomienda resolver 031–033, aumentar pruebas de interacción reales y completar las comprobaciones de datos históricos y accesibilidad. Esta pasada es documental: no modifica comportamiento, migraciones ni datos de producción; sin fusión de ramas.

## Adecuaciones de la tercera reauditoría — 2026-11-10 (CATEGORIES-031–033)

**Rama:** `feature/fixes`. Alcance limitado al catálogo Categorías, su controlador, Stimulus, CSS, pruebas y este expediente. **No se fusionan ramas ni se modifican migraciones**.

| ID | Cambio aplicado | Regresión añadida | Estado |
|---|---|---|---|
| CATEGORIES-031 | Selector compacto de orden visible solo cuando la tabla se sustituye por tarjetas (≤1099 px). Mantiene nombres/códigos y otros órdenes compatibles mediante etiquetas ya traducidas es/en/ko, utilizando el dropdown visual estándar. El panel «Filtros avanzados» permanece eliminado. | Chrome a 390 y 768 px: dropdown, cambio a Código descendente, estado oculto y chip activo; request verifica selector sin `name` para no alterar la búsqueda. | Implementado; CI del SHA pendiente |
| CATEGORIES-032 | `paginate` publica `@current_page` real, renderizado en `data-categories-current-page`; `categories-search#syncResults` alinea la URL con esa página después de un Turbo Frame/Stream. Buscar o cambiar estado desde `?page=3` elimina `page` cuando el servidor muestra la primera. Navegación explícita a otra página mantiene el estado. | Request compara páginas 3 y 1; Chrome parte de `?page=3`, filtra y verifica DOM y query string. | Implementado; CI del SHA pendiente |
| CATEGORIES-033 | `broadcast_categories_update` se emite inmediatamente después de notificar una mutación guardada y **antes** de la redirección por ausencia de `index?`. No se envían resultados a quien carece del permiso de consulta: solo se publica señal de actualización acotada por organización. | Request con permiso granular sin `categories.index`: GET 403, altas/ediciones/bajas exitosas y tres broadcasts a la organización autorizada. | Implementado; CI del SHA pendiente |

**Puertas abiertas preexistentes:** CATEGORIES-001/009 requieren validar backfill y constraints sobre copia de datos históricos; CATEGORIES-029 requiere contraste real por temas; CATEGORIES-010, foco de modal, zoom 200 % y lector de pantalla requieren verificación manual independiente. Los fallos de Clientes y Productos en suites compartidas se registran EXTERNOS y no se omiten.

**Dictamen provisional:** ADECUACIONES IMPLEMENTADAS; NO CERRADO hasta resultado focalizado y CI global del SHA, más revisión de accesibilidad/datos históricos.
