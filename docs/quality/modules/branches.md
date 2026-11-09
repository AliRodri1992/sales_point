# Registro de calidad — Sucursales (`/admin/branches`)

- **Módulo:** Sucursales — rutas propias `/admin/branches`.
- **Alcance:** listado, nueva sucursal, edición, detalles, eliminación lógica, selección, filtros, búsquedas, paginación, sugerencias postales y acciones de cambio de estado expuestas en estas rutas.
- **Secciones que se renderizan en detalles:** domicilio/contacto/notas; sección de terminales **solo tal como se ofrece desde Sucursales**.
- **Propietario:** módulo Sucursales. **Revisión independiente:** pendiente.
- **SHA de partida del estándar:** `de54c086229cc3d5a8f2c4cb9df034b268a83f43` (base previa a la documentación).
- **SHA de aceptación:** PENDIENTE.
- **Estado del módulo:** **IMPLEMENTADO, PENDIENTE DE VERIFICACIÓN**; **NO CERRADO**.
- **Última revisión:** 2026-11-08; registro inicial de calidad, no ejecución de auditoría nueva.

> Este registro inicia el seguimiento modular. Las auditorías previas fueron principalmente estáticas y varias correcciones se publicaron sin una ejecución de RSpec, RuboCop, navegador y CI confirmada para el mismo SHA. **No se infiere ausencia de defectos.**

## 1. Frontera de la auditoría

| Ruta/acción propia | Qué debe revisarse | Código principal | Pruebas existentes |
|---|---|---|---|
| `GET /admin/branches` | Acceso, listado, resultados, búsqueda, filtros combinados, ordenación, paginación, móvil, estados vacío/carga/error | `Admin::BranchesController#index`, `Admin::BranchFilters`, `Admin::BranchesListing`, `app/views/admin/branches/_list.html.erb` y `_filters.html.erb`, `branch_directory_controller.js` | `spec/requests/admin/branches_spec.rb` |
| `GET /admin/branches/new` y `POST /admin/branches` | Validaciones de modelo, dirección/teléfono principales, código automático, errores individuales, 422 y persistencia | `Admin::BranchesController`, `Branch`, formulario y parciales de `app/views/admin/branches/` | `spec/requests/admin/branches_spec.rb`, `spec/models/branch_spec.rb` |
| `GET /admin/branches/:id/edit` y `PATCH /admin/branches/:id` | Precarga y conservación de datos, permisos, validaciones anidadas, mensajes por campo, cambio concurrente | Controlador, `Branch`, formulario y parciales | `spec/requests/admin/branches_spec.rb` |
| `GET /admin/branches/:id` | Datos propios, presentación, permisos, historial, navegación y acciones visibles | `show.html.erb`, `BranchesHelper`, `Admin::BranchAudits`, `BranchPolicy` | `spec/requests/admin/branches_spec.rb` |
| `DELETE /admin/branches/:id` | Confirmación, permisos, dependencias directas, soft delete y retroalimentación | `Admin::BranchesController#destroy`, `Branch`, `BranchPolicy` | `spec/requests/admin/branches_spec.rb`, `spec/models/branch_spec.rb` |
| `PATCH /admin/branches/:id/transition_status` | Opciones válidas, razón, permisos, restricciones de cierre/suspensión y mensajes de bloqueo | `Admin::BranchTransitions`, `Branches::TransitionStatus`, `Branches::LifecycleRequirements` y sección de estado de `show` | `spec/services/branches/transition_status_spec.rb`, `spec/services/branches/lifecycle_requirements_spec.rb`, `spec/requests/admin/branches_spec.rb` |
| `PATCH /admin/branches/:id/select` y sugerencias postales | Seguridad/alcance de la selección, respuesta de ayuda postal y errores | Acciones de Sucursales y `Admin::BranchSupport` | `spec/requests/admin/branches_spec.rb` |
| Acciones de terminal **incrustadas en `/admin/branches/:id`** | Que los botones funcionen, muestren errores correctamente, tengan permiso y respeten estado de sucursal | `Admin::BranchTerminals` y `app/views/admin/branches/_terminal_management.html.erb` | `spec/requests/admin/branch_terminals_spec.rb` |

Incluido: permisos, datos y validaciones que estas rutas usan directamente; accesibilidad, CSS/JS utilizados, i18n `es/en/ko`, contratos mínimos y pruebas. Excluido: auditoría interna completa de Terminales, Onboarding, Inventario, Purchases, FEFO, lotes, recepciones, finanzas, etc.

## 2. Contratos externos: límite, no expansión

| Contrato relevante desde Sucursales | Solo verificar en este expediente | Propietario del módulo interno |
|---|---|---|
| Terminales | Las acciones de terminales **de la pantalla de Sucursales** respetan permisos, estado, mensajes, confirmaciones y errores | Auditoría propia de Terminales |
| Onboarding | La sucursal creada inicialmente puede validarse/usarse en rutas normales sin romper las precondiciones de Sucursales | Auditoría propia de Onboarding |
| Inventario | El requisito para cerrar la sucursal reconoce que hay existencias pendientes y lo explica, sin inspeccionar los algoritmos internos | Auditoría propia de Inventario |
| Compras / Purchases | Los pedidos, solicitudes y devoluciones pendientes se reflejan correctamente como impedimentos de cierre | Auditoría propia de Purchases |
| Organización/roles | No acceder a sucursales de otras organizaciones; permiso correcto para cada acción propia | Contrato de autenticación/autorización, sin auditoría completa de Usuarios |

Un fallo interno de otro módulo se registra **EXTERNO** y se transfiere a su responsable. Si vuelve rojo CI, detiene el cierre de esta entrega, pero **no se transforma en error de Sucursales**.

## 3. Registro de hallazgos y verificación

**No hay un dictamen funcional final bajo este estándar.** No se han documentado resultados actuales de RSpec o navegación para el SHA de partida. Las siguientes entradas son **riesgos de verificación**, no fallos reproducidos.

| ID | Prioridad | Clase y evidencia | Criterio de cierre | Estado |
|---|---|---|---|---|
| `BR-001` | P2 | **Por verificar**, UI de filtros/paginación: falta evidencia de navegación real, carga, vacío, error, reintento y móvil de `/admin/branches` | Comprobar resultados, foco y recuperación en navegador y registrar capturas/resultado | PENDIENTE |
| `BR-002` | P2 | **Por verificar**, formularios nueva/editar: modelos y mensajes individuales presentes en código, aún sin evidencia visual y 422 real consolidada | Verificar reglas por campo (sin resumen duplicado), dirección, teléfono, localizaciones y persistencia | PENDIENTE |
| `BR-003` | P2 | **Por verificar**, detalles/cambio de estado: formulario consolidado y confirmación JS requieren prueba real de selección, mensaje, confirmación, motivo y bloqueo | Ejecutar flujo de teclado y un cambio de estado autorizado/no autorizado sin tocar otros módulos | PENDIENTE |
| `BR-004` | P2 | **Por verificar**, historial/soft delete/terminales de la vista de sucursal, sin smoke visual completo | Verificar restricciones y permisos en la ruta propia, eventos y textos accesibles | PENDIENTE |
| `BR-005` | P1 de proceso | **Sin evidencia de aceptación**, CI completo, RSpec, RuboCop, I18n, seguridad y prueba visual en SHA final | Vincular comprobaciones reales y verdes del SHA exacto; o conservar estado NO CERRADO | PENDIENTE |

No se afirma que BR-001 a BR-004 sean defectos confirmados. Cuando un caso falle, registrar causa raíz, reproducción, archivos, spec, commit y estado **bajo el mismo ID**. Si aparece una causa distinta, agregar `BR-006`, `BR-007`, etc., sin reiniciar el documento.

## 4. Checklist de cierre por ruta

### Listado / filtros / paginación
- [ ] Aislamiento organizacional, visibilidad por rol, filtros combinados, fechas inválidas, ordenación y tamaños de página.
- [ ] Tabla escritorio y tarjetas móviles; búsqueda, resultados y acciones accesibles.
- [ ] Carga, error 401/403/404 y error de red; reintento, foco, estado vacío, cambios historial atrás/adelante.

### Nueva / Editar
- [ ] Todos los campos con reglas del **modelo/servidor**, asterisco rojo en obligatorios, mensaje **debajo del campo** («nombreCampo mensajeValidación»).
- [ ] No usar `required` de HTML5 para suplir modelo; no duplicar errores en un resumen.
- [ ] Código autogenerado estable; dirección fiscal/ubicación y teléfono principal guardados correctamente; retención de entradas ante 422.
- [ ] Precarga de edición, validación completa y permisos, soft deletion y datos de organización.

### Detalle / estados / acciones de sucursal
- [ ] Contenido y navegación, teléfono/correo/domicilio/notas, historial, traducciones es/en/ko.
- [ ] Eliminación y cambios de estado: confirmación contextual, razón, reglas del servicio, mensajes claros y retorno a pantalla.
- [ ] Acciones de terminales **solo dentro del detalle**: permisos, confirmaciones y errores por campo.
- [ ] Contratos externos mínimos para bloqueo de activación/suspensión/cierre (sin auditar los módulos vecinos).

### Calidad de cierre
- [ ] RSpec focalizado (con SHA, log y resultado PASÓ).
- [ ] RuboCop, auditorías de seguridad e i18n (con SHA/log y resultado PASÓ).
- [ ] CI completo para el SHA candidato **verde**.
- [ ] Browser real: escritorio/móvil, teclado, lector de pantalla cuando disponible, zoom 200 %, errores y éxito.
- [ ] P0/P1 conocidos cerrados; P2 resueltos o aceptados por propietario; reauditoría de regresiones.
- [ ] Revisor independiente y fecha de aprobación registrados.

## 5. Ejecución y evidencia (aún pendiente)

| Comprobación | Comando / fuente | Resultado | Evidencia |
|---|---|---|---|
| RSpec de rutas | `bash bin/overcommit-rspec spec/requests/admin/branches_spec.rb spec/requests/admin/branch_terminals_spec.rb` | **NO EJECUTADO bajo este registro** | Pendiente |
| Reglas de modelo/estado | `bash bin/overcommit-rspec spec/models/branch_spec.rb spec/services/branches/transition_status_spec.rb spec/services/branches/lifecycle_requirements_spec.rb` | **NO EJECUTADO bajo este registro** | Pendiente |
| RuboCop | `docker compose -f docker-compose.dev.yml exec web bundle exec rubocop` | **NO EJECUTADO bajo este registro** | Pendiente |
| Auditoría UI real | Navegador en `/admin/branches`, `/new`, `/:id`, `/:id/edit` | **NO EJECUTADO bajo este registro** | Pendiente |
| CI completo | `.github/workflows/ci.yml` sobre SHA final | **NO CONFIRMADO** | Pendiente |
| Seguridad / I18n | Jobs específicos de CI | **NO CONFIRMADO** | Pendiente |

**Nota:** una prueba de integración con otros modelos solo valida el contrato de Sucursales; no reemplaza auditorías futuras de Onboarding, Inventario, Terminales o Purchases.

## 6. Dictamen

**NO CERRADO — IMPLEMENTADO PENDIENTE DE VERIFICACIÓN**.

- **P0/P1 funcionales confirmados por ejecución:** no determinados; **no equivale a cero**.
- **Riesgos/controles pendientes:** `BR-001` a `BR-005`.
- **SHA final y evidencia CI:** PENDIENTES.
- **Aceptación independiente:** PENDIENTE.
- **Reapertura:** si un hallazgo reaparece, se reabre el mismo ID y se conserva el historial.

Ver las [reglas de cierre](../module-quality-standard.md) y la [plantilla](../module-audit-template.md).

## Revisión focalizada de presentación — 2026-11-08

- **Alcance:** `GET /admin/branches/:id`, sección Estado operativo. AI Dev Suite aplicado como metodología Impeccable + UI UX Pro Max + Ponytail; no se ejecutaron las CLIs externas.
- **BR-003 (ampliación, mismo ID):** confirmado por inspección estática que la tarjeta de estado operativo estaba inmediatamente debajo del encabezado y carecía de reglas propias de separación/ritmo interior. Se introducen clases `branch-lifecycle-body`, `branch-lifecycle-heading`, `branch-lifecycle-description` y estilos acotados responsive en `branch_workspace.css`; no se modifican transiciones, permisos ni módulos vecinos.
- **Regresión añadida:** `spec/requests/admin/branches_spec.rb` valida estructura de encabezado, descripción y panel operativo; **NO EJECUTADA** desde este entorno. Requiere prueba visual de escritorio/móvil, foco, zoom y ejecución de CI del SHA final antes de marcar BR-003 verificado.
- **Estado:** CAMBIO IMPLEMENTADO, PENDIENTE DE VERIFICACIÓN; las demás comprobaciones BR-001 a BR-005 continúan vigentes.


## Auditoría transversal AI Dev Suite — 2026-11-08 (segunda ronda)

- **Rama y SHA inspeccionados:** `feature/fixes`, `3c31725cdf41ef0c2b45caa33df6e0b3735a931d`. **SHA de aceptación:** PENDIENTE.
- **Método:** lectura de código y documentación vía GitHub + inspección de logs reales de GitHub Actions. Procedimientos de AI Dev Suite: Impeccable (UI/estados/accesibilidad), UI UX Pro Max (consistencia y responsive), Ponytail (simplicidad, lógica, consultas y regresiones). **No se ejecutaron sus CLIs originales ni navegador local**.
- **Propiedad:** exclusivamente rutas `/admin/branches` (index/new/create/show/edit/update/destroy/select/transition_status/postal_suggestions y acciones de terminal en la pantalla de detalle); servicios de estado y componentes directamente consumidos. Inventario, Compras, Onboarding, Usuarios y Terminales autónomas quedan fuera salvo contrato observable.

### Resultado del inventario estático

| Superficie propia | Revisión realizada | Resultado / límite |
|---|---|---|
| Directorio, filtros, búsqueda y paginación | `BranchesController`, `BranchFilters`, `BranchesListing`, `index`, `_filters`, `_list`, `branch_directory_controller.js` | Filtros normalizados en servidor; orden limitado a columnas predefinidas; abort de solicitudes obsoletas, skeleton y reintento presentes. Falta navegación real y medir consultas |
| Alta/edición | `BranchForm`, `Branch`, `BranchLifecycle`, `_form`, `_phone_fields` | Parámetros permitidos explícitos, `novalidate` y validaciones principales de modelo; error 422 representado en vista. Falta recorrer errores por cada país/teléfono y comprobar persistencia por navegador |
| Ver sucursal/Estado operativo | `show`, `BranchesHelper`, `branch_workspace.css`, `branch_transition_controller.js` | Espaciado focalizado BR-003 ya implementado; hay resumen de requisitos, estados/bloqueos y confirmación dinámica. Sin validación visual, teclado ni zoom 200 % |
| Ciclo de vida, eliminación y auditoría | `TransitionStatus`, `LifecycleRequirements`, `BranchLifecycle`, `BranchAudits`, `BranchPolicy` | Transiciones con bloqueo, actor, motivo y registros; eliminación lógica restringida; permisos y scopes presentes. Faltan pruebas end-to-end y aceptación de concurrencia en SHA final |
| Terminales incrustadas | `BranchTerminals`, `_terminal_management` | Restringe alta/activación según estado y utiliza validaciones del modelo. Solo verificar contrato desde la pantalla de sucursal |

### Hallazgos y seguimientos (IDs persistentes)

**BR-001 · P2 · UI del directorio — PENDIENTE DE REPRODUCCIÓN.** Hay implementación de carga, error, reintento, filtros y controles móviles, pero faltan evidencias de teclado, atrás/adelante, rapidez, composición IME, errores y actualización correcta de controles tras las respuestas Turbo. No registrar un fallo funcional antes de reproducirlo.

**BR-002 · P2 · Alta/edición — PENDIENTE DE REPRODUCCIÓN.** Las validaciones de modelo, etiquetas y mensajes por campo están presentes en el código revisado; ejecutar matriz por país (MX/otros), dirección, celular, email, nombre duplicado, 422, actualización y preservación de datos. No se ha demostrado que falle cada caso.

**BR-003 · P2 · Estado operativo — CAMBIO IMPLEMENTADO / NO VERIFICADO.** Mantener la corrección anterior de espaciado. La vista recalcula `branch_transition_blockers` al renderizar avisos, elegir estado y generar opciones. Ver BR-007 por coste de consultas. Validar confirmación dinámica, motivos, anuncio de bloqueos, foco, responsive y estados vacíos.

**BR-004 · P2 · Historial/soft delete/terminales — PENDIENTE DE REPRODUCCIÓN.** Existen protecciones y request specs, pero faltan pruebas UI integrales de 403/404/422, registros, confirmación y operaciones bloqueadas. Mantener dueño separado para lógica interna de los otros módulos.

**BR-005 · P1 de proceso · ACEPTACIÓN CI — BLOQUEADO.** En el SHA inspeccionado, job global RuboCop **FALLÓ** (55 ofensas en 1123 archivos). Job RSpec estaba **EN EJECUCIÓN** al consultar; I18n/YAML, seguridad y migraciones limpias/semillas **PASARON**. Evidencia: https://github.com/AliRodri1992/sales_point/actions/runs/42556277587 . Hay errores de sintaxis RuboCop en `spec/services/inventories/fefo_allocator_spec.rb` y `spec/services/purchases/receive_spec.rb`: **EXTERNOS**; bloquean CI pero no se atribuyen a Sucursales. No certificar cierre con ese SHA.

**BR-006 · P1 de calidad · RuboCop propio — CONFIRMADO POR CI, ABIERTO.** El log de RuboCop reporta ofensas directamente en `app/controllers/admin/branches_controller.rb` (filtro de acciones definido en concerns), `app/controllers/concerns/admin/branch_audits.rb` (Performance/ReverseFirst), `app/helpers/branches_helper.rb` (complejidad y uso de variable de instancia), `app/models/branch.rb` (formato/WhereExists), `app/models/concerns/branch_lifecycle.rb` (asociación sin política `dependent`), `app/services/branches/lifecycle_requirements.rb` (complejidad y consultas), así como specs de modelo y concurrencia (espacios). Corregir sin cambiar las reglas de estado ni borrar historial; comprobar con RuboCop focalizado, RSpec y CI. **Evidencia:** https://github.com/AliRodri1992/sales_point/actions/runs/42556277587/job/128962631510 .

**BR-007 · P2 de rendimiento · Cálculo reiterado de bloqueos — RIESGO CONFIRMADO POR CÓDIGO, IMPACTO NO MEDIDO.** `show.html.erb` invoca varias veces `branch_transition_blockers` por estado, que a su vez construye `LifecycleRequirements` y consulta membresías, terminales, inventarios, órdenes y roles. Consolidar los resultados una sola vez por estado en la solicitud, reutilizarlos en advertencias/selector/botón, y medir consultas con specs para estados `preparing`, `active`, `suspended` y `closed`. No atribuir un tiempo de respuesta sin medición.

**BR-008 · P3 de navegación · Estado operativo no incluido en enlaces de sección — CONFIRMADO POR CÓDIGO.** `show.html.erb` crea navegación anclada solamente a `identity/contact/location/notes/operations`, aunque la sección operativa tiene título e ID. Revisar si conviene incluir ancla al panel, especialmente para móvil y teclado, y mantener nombres i18n. Requiere revisión visual antes de cambio final.

### Verificación y dictamen

| Fuente | Resultado real al consultar | Alcance |
|---|---|---|
| Revisión estática de rutas, controlador, helpers, modelo, servicio, vistas, JS y CSS | REALIZADA | Evidencia de código; no ejecución |
| GitHub Actions `RuboCop` del SHA base | **FALLÓ** · 55 ofensas | Incluye propios y externos |
| GitHub Actions `Security scans` | **PASÓ** | General, no sustituye prueba de seguridad focalizada |
| GitHub Actions `Rails I18n and YAML audit` | **PASÓ** | General, no sustituye comprobación visual de traducciones |
| GitHub Actions `Fresh migrations and seed data` | **PASÓ** | General |
| GitHub Actions `RSpec` | **EN EJECUCIÓN** al momento de consulta | No inferir aprobación |
| Pruebas focalizadas de Sucursales y navegador real | **NO EJECUTADAS en esta ronda** | Pendientes |

**Dictamen de esta ronda: AUDITADO ESTÁTICAMENTE; NO VERIFICADO; NO CERRADO.** No se cambió la funcionalidad; este registro es diagnóstico. No hay evidencia suficiente para afirmar ausencia de defectos P0/P1. Retomar los mismos IDs en la corrección y reauditoría, sin duplicarlos.


**Actualización CI posterior a la consulta inicial:** el job global RSpec del SHA `3c31725` terminó **CANCELADO** (no aprobado), tras haberse observado inicialmente en ejecución. La nueva actualización documental genera otro SHA; sus propios checks requieren consulta separada. Se conserva el historial de ambos estados para trazabilidad.


## Adecuaciones BR-006 / BR-007 / BR-008 — 2026-11-08

**Estado:** IMPLEMENTADO SIN VERIFICAR. Se conserva el historial de BR-001 a BR-005 y el dictamen NO CERRADO; el commit de adecuación deberá validarse en CI y navegador.

- **BR-006:** corregidas las ofensas identificadas en archivos de Sucursales: filtro de acciones en concerns, ordenación de auditoría, complejidad y variable de instancia de helper, orden/consultas de modelo y dependencia del historial, complejidad y `exists?` del servicio de estado, y formato de specs. Se preservan las reglas de transición y el historial. **RuboCop focalizado: PENDIENTE.**
- **BR-007:** requisitos y bloqueos calculados desde `load_branch_detail` una vez por transición; reutiliza requisitos de activación y los resultados en la vista. Añadidas pruebas de regresión sobre la creación del servicio y la equivalencia de bloqueos. **Medición real de consultas y RSpec: PENDIENTES.**
- **BR-008:** Estado operativo incorporado a la navegación anclada del detalle, ahora antes de las tarjetas; separación escritorio/móvil reajustada, prueba estructural ampliada. **Revisión visual/teclado/zoom 200 %: PENDIENTE.**
- **BR-001 / BR-002 / BR-003 / BR-004:** siguen sin verificarse integralmente; conservar las comprobaciones manuales.
- **BR-005:** requiere CI global verde para el SHA final. Hallazgos internos de otros módulos son EXTERNOS y no justifican ampliar esta modificación.

**Los cambios no incluyen merge ni certifican cierre técnico.**


### Segunda pasada RuboCop — 2026-11-08

En el SHA `1123a0e9e4c762a02d8f044396c94bc59dc4da20` el job de RuboCop global registró **40 ofensas** (frente a 55 de la revisión previa). Persistían siete señalamientos en Sucursales: longitud y complejidad del controlador, `before_action` de concern, complejidad del formateo de auditoría y uso de `map` en un spec. Esta pasada separa `Admin::BranchDetail`, usa un predicado explícito para cargar la sucursal y simplifica el formateo de eventos. **Pendiente de comprobar en el próximo CI**.

Los errores de otros módulos continúan identificados como EXTERNOS. Los IDs `BR-006`, `BR-007` y `BR-008` conservan su estado **implementado sin verificar**, no cerrado.


## Adecuaciones pendientes BR-001 / BR-002 / BR-003 / BR-004 / BR-005 — ronda de regresión focalizada

- **BR-001:** actualizados los specs de filtros de estado operativo de `inactive` a `suspended`; las comprobaciones de navegación, error/reintento, paginación, filtros dependientes y viewport móvil quedan incluidas en `spec/features/branch_workspace_browser_spec.rb`.
- **BR-002:** corregidas expectativas obsoletas de código manual/estado inicial de nueva sucursal. Un rechazo de unicidad de base de datos con datos válidos ahora se presenta como error junto al nombre, no como error `base` invisible. Pruebas de 422 y conservación de valores actualizadas.
- **BR-003:** la prueba de navegador mantiene revisión de detalle móvil y verifica la navegación a Estado operativo. Las transiciones se someten a specs de request con bloqueos reales.
- **BR-004:** corregidos specs de desactivación para que usen la ruta autorizada `transition_status`, prueben restricciones de personal/terminal y mantengan el estado del registro; la manipulación de estado vía `PATCH /admin/branches/:id` se verifica como ignorada.
- **BR-005:** creado `.github/workflows/branches-ci.yml` para RuboCop focalizado y RSpec de modelo, servicios, requests y navegador Chrome, independiente del CI global. **No se declara PASÓ hasta revisar los jobs del SHA exacto.**
- **Estado:** IMPLEMENTADO, PENDIENTE DE VERIFICACIÓN POR ACTIONS. Sin merge; fallos de dominios ajenos se conservan como EXTERNOS.


### Resultado de Branches CI y segunda corrección

- **Commit de primera ejecución:** `bacf2da050a8821e2cb9925f7df3f97ff0898c1c` (https://github.com/AliRodri1992/sales_point/actions/runs/42559852438).
- **Branches module RuboCop:** APROBADO.
- **RSpec focalizado con navegador:** **129 ejemplos; 6 fallos**. Fallos localizados en `branch_workspace_spec` (badge y tampering), navegación de ancla del detalle (Chrome), bloqueo concurrente Branch/Organization (deadlock PostgreSQL), fixture de eliminación incompatible con transición obligatoria, y ausencia de retiro en historial de Phone/Note.
- **Adecuaciones:** la prueba de badge se ajusta al diseño actual, las peticiones solo con atributos prohibidos se esperan como 400, los enlaces de secciones evitan interceptación Turbo, el orden de locks de `Branches::TransitionStatus` es Branch → Organization (conservando bloqueo global), el fixture realiza soft delete de sucursal `preparing` sin asignaciones inválidas. Para BR-004, las pruebas comprueban explícitamente que PaperTrail registre actualizaciones de Phone/Note, facilitando la identificación de la causa de historial.
- **Estado:** FIX IMPLEMENTADO; segunda ejecución de Branches CI todavía **NO VERIFICADA**. No se considera cerrado ninguno de los IDs pendientes hasta revisión del SHA exacto. Fallos externos al módulo permanecen fuera de esta corrección.


### Tercera pasada de verificación

En el SHA `5f3a52a4748d8d679aad68ef660d6e2704446724` Branches CI ejecutó **129 ejemplos / 2 fallos**: arreglados la concurrencia y el selector de sucursales, quedan el historial de bajas de teléfonos/notas y el fragmento de navegación. La comprobación Capybara de `current_path` no retiene fragmentos de URL, por lo que se reemplaza por `:target` y `window.location.hash` tras la espera. Se añaden comprobaciones del contenido `changeset` de PaperTrail y de búsquedas `with_deleted` para identificar cuál etapa descarta eventos de baja. RuboCop marcó una interpolación en el spec de navegación; ya no se usa concatenación. **Esta ronda requiere nuevo Branches CI verde; no cerrar aún.**


### Causa raíz del historial de bajas — BR-004

En `ecd15e869ea33f5f798053d70d03c8b1f6618f8e`, **128/129 pruebas pasaron**. El test de historial verificó que PaperTrail sí almacenaba una versión `update` de `Phone`, pero `version.changeset` retornó vacío, por lo que la vista no pudo mostrar `deleted_at` → «Retirado». Se delimita el cambio al rastro de teléfonos/notas **cuando pertenecen a Branch** y se exige conservar el diff de `number/kind/primary/whatsapp_enabled/deleted_at` o `body/deleted_at`. La verificación se mantiene en la prueba de historial; esta implementación NO equivale a aprobación hasta el nuevo CI.


### Resolución del historial BR-004 — lectura segura de versiones

PaperTrail 17.0.0 almacenó los diffs de baja como YAML con marcas `!ruby/object:ActiveSupport::TimeWithZone`. El test constató que `object_changes` contiene `deleted_at` mientras `version.changeset` devolvía `{}`, de modo que `Admin::BranchAudits` descartaba cambios de Phone y Note. La corrección incorpora un fallback **YAML.safe_load** con una lista restringida de clases temporales y control de excepciones, limitado a los eventos que el lector actual no pudo decodificar; no usa `unsafe_load` ni modifica versiones almacenadas.

Se ajustan las expectativas de RSpec para verificar el diff crudo y el historial visible de teléfonos/notas retirados. **Estado: implementación pendiente de nueva verificación CI.**


### Revisión de cierre automatizado y ajuste de accesibilidad — 2026-11-08

**Evidencia verificada sobre SHA `d7d232239de28132d758b85ca11cd648e9ce7101`:** `Branches CI` [42562001041](https://github.com/AliRodri1992/sales_point/actions/runs/42562001041) **PASÓ**, con `Branches module RuboCop` **PASÓ** y `Branches models, requests and real browser flows` **129 ejemplos, 0 fallos** (seed 60103). También aprobaron en CI global para ese SHA seguridad, I18n/YAML y migraciones/semillas. Esto sustituye las notas de «no ejecutado» para el alcance de la suite focalizada, sin alterar sus datos históricos.

- **BR-001:** regresiones reales de Chrome para filtros AJAX, foco retenido, error/reintento, paginación, filtros dependientes y móvil. La mejora de esta ronda añade `role="status" aria-live="polite" aria-atomic="true"` al encabezado de recuento para informar el cambio a tecnologías de asistencia; nueva prueba Chrome pendiente de CI.
- **BR-002:** regresiones reales para alta/edición, código autogenerado, reglas por país, 422, red de errores por campo y persistencia; **VERIFICADO AUTOMÁTICAMENTE** para escenarios representados por specs, no toda la matriz exploratoria.
- **BR-003:** ancla de Estado operativo, espacio móvil y transiciones verificadas mediante request y Chrome; **VERIFICADO AUTOMÁTICAMENTE** para los escenarios representados, sin auditoría manual de zoom 200 % ni lector de pantalla.
- **BR-004:** historial de bajas Phone/Note, confirmaciones y contratos de permisos/transiciones probados en la suite focalizada; **VERIFICADO AUTOMÁTICAMENTE** para dichos escenarios.
- **BR-006, BR-007, BR-008:** RuboCop focalizado, lógica de bloqueos y navegación incluidos en la suite de 129 ejemplos; **VERIFICADOS AUTOMÁTICAMENTE** para los casos ensayados.
- **BR-005 (aceptación):** sigue **ABIERTO** porque la ejecución global `CI` no fue verde; la rama sigue recibiendo cambios paralelos. No reinterpretar fallas de otros módulos como Sucursales; sí detienen el cierre integral conforme al estándar.

**Dictamen:** corregido y probado en la superficie cubierta por Branches CI; verificación manual exploratoria de 200 % de zoom, lector de pantalla y escenarios no automatizados sigue pendiente. No marcar cierre independiente ni fusionar.


### Resultado real de la nueva regresión accesible — 2026-11-08

Sobre el commit `7299330c52f4c831eb6c84d3aedeacb188a723a6`, Branches CI [42562487952](https://github.com/AliRodri1992/sales_point/actions/runs/42562487952) **APROBÓ** ambas tareas: RuboCop específico de Sucursales y RSpec de modelos, servicios, requests y Chrome, con **130 ejemplos y 0 fallos** (seed `7456`). La regresión `announces updated result counts to assistive technology after filtering` validó el `role=status`, `aria-live=polite`, `aria-atomic=true`, el recuento actualizado y la preservación del foco al filtrar.

**BR-001:** mejora de accesibilidad IMPLEMENTADA Y VERIFICADA AUTOMÁTICAMENTE. **BR-002/BR-003/BR-004/BR-006/BR-007/BR-008:** escenarios incluidos en Branches CI, verificados automatizadamente en el SHA indicado, sin sustituir pruebas manuales de lector de pantalla, zoom real 200 % o una revisión independiente. **BR-005 permanece ABIERTO** porque el CI global no ha sido certificado verde en SHA de aceptación; las cancelaciones por trabajo concurrente y ofensas de módulos externos no se atribuyen a Sucursales. Ningún merge efectuado.


## Reauditoría de Sucursales con AI Dev Suite — 2026-11-08 (SHA 72d1ff14)

**Punto de partida:** rama `feature/fixes`, `72d1ff14cdab537ff7174e814ed3674fec4bb47f`. **Método:** AI Dev Suite aplicado como procedimientos Impeccable (jerarquía, teclado y estados), UI UX Pro Max (formularios, diseño y responsive) y Ponytail (controlador, permisos, consultas y pruebas). Lectura de implementación y especificaciones mediante GitHub, comparación de commits y revisión de **logs reales** de Actions. **No** se ejecutaron los CLI externos de las suites ni se navegó al servidor local; Chrome automatizado corresponde a ejecuciones registradas de CI, no a una sesión manual de esta ronda.

### Cobertura revisada

- **Listado / BR-001:** `Admin::BranchFilters`, `Admin::BranchesListing`, `_filters`, `_filter_badges`, `_list`, `branch_directory_controller.js`, pruebas de solicitudes y Chrome para búsqueda, combinaciones, paginación, retroceso, errores/red, reintento, foco y 390 px.
- **Alta/edición / BR-002:** `BranchForm`, `Branch`, `Address`, `Phone`, `_form`, `_phone_fields`: validaciones Rails, `novalidate` sin `required` HTML5, asteriscos y errores por campo, códigos generados, dirección por país, persistencia, cambios concurrentes y permisos. No se observó un nuevo incumplimiento confirmado por ejecución.
- **Ver sucursal/estado / BR-003, BR-007, BR-008:** `show`, `BranchDetail`, `Branches::LifecycleRequirements`, `Branches::TransitionStatus`: panel con separación propia, navegación a Estado operativo, motivo/bloqueos, restricciones, renderizado de historial y acciones embebidas.
- **Historial / BR-004:** `BranchAudits`, `_change_history`, soft deletion de Phone/Note y permisos de la vista; se conserva el fallback YAML seguro y la prueba de auditoría. Terminales exclusivamente desde `/admin/branches/:id`.
- **Frontera:** dependencias de Roles/membresías, inventario/compras y servicios de terminales solo al nivel de contrato. No se reabrieron módulos vecinos.

### Hallazgos de la ronda (IDs existentes)

| ID | Evidencia y clasificación | Prioridad | Estado |
|---|---|---|---|
| **BR-001** | **CONFIRMADO POR CÓDIGO, accesibilidad:** `app/views/admin/branches/_list.html.erb` usa un `<h2 id="branches-result-title" role="status" aria-live="polite">`. El rol explícito `status` sustituye el rol semántico `heading`: el título ya no se expone como encabezado de nivel 2 para navegación por encabezados en tecnologías de asistencia. La prueba existente comprueba el atributo, **no** esa semántica ni anuncios reales. | **P2** | **REABIERTO, por corregir.** Mantener `h2` semántico y mover el aviso de resultados a una región viva persistente separada; añadir prueba semántica y verificar con lector real. |
| **BR-002** | Modelo Rails y respuestas 422 con errores por campo presentes; escenarios de país, dirección, correo, teléfono, código, precarga y permisos cubiertos parcialmente por RSpec/Chrome anterior. No se constató un defecto nuevo en esta lectura. | P2 histórico | **AUTOMATIZADO PREVIAMENTE; exploración manual pendiente.** |
| **BR-003** | **CONFIRMADO POR CÓDIGO, UX:** `show.html.erb` permite motivo de transición de hasta **2,000 caracteres**, pero lo presenta como `transition_form.text_field :reason` (una línea). Esto dificulta revisar y editar justificaciones largas. Espaciado de Estado operativo y navegación móvil están incluidos en Chrome anterior, pero no equivalen a revisión visual manual/zoom. | **P3** | **AMPLIADO bajo el mismo ID.** Preferir `text_area` con altura adaptable y conservar error debajo del campo, longitud máxima y `aria-describedby`; probar móvil. |
| **BR-004** | Restricciones de baja, historial PaperTrail de Phone/Note y acciones embebidas se aprobaron en Branches CI anterior. `Phone`/`Note` recibieron cambios de formato posteriores sin comportamiento nuevo observado; `UserRole`/membresías sí cambiaron sus contratos de asignación. | P2 histórico | **AUTOMATIZADO PREVIAMENTE; revalidar tras cambios de dependencias.** |
| **BR-005** | **BLOQUEO EXTERNO CONFIRMADO EN LOG.** En Branches CI [42562766963](https://github.com/AliRodri1992/sales_point/actions/runs/42562766963), RuboCop propio **PASÓ**, pero el job Chrome/RSpec falló **antes de ejecutar tests**: `ActiveRecord::InvalidMigrationTimestampError`, `20261111000000_scope_user_roles_by_organization.rb`, timestamp superior al máximo admitido `20261110043730`. Dueño: **Roles/migraciones**, no lógica de Sucursales. CI global del SHA más reciente tampoco está certificado verde. | P1 proceso | **ABIERTO / BLOQUEADO POR EXTERNO.** Coordinar corrección de fecha/versión de migración con dueño de Roles y repetir CI sobre el mismo SHA final. |
| **BR-006** | RuboCop de Sucursales sin ofensas en los checks especializados verdes y en la ejecución posterior fallida por migración. | P1 histórico | **VERIFICADO EN CI FOCALIZADO**, cierre formal condicionado a BR-005. |
| **BR-007** | El controlador compone bloqueos por transición una vez en `Admin::BranchDetail`; regresión de comportamiento presente. No hay medición documentada de presupuesto SQL específico del detalle bajo cargas mayores. | P2 histórico | **IMPLEMENTADO / REGRESIÓN ANTERIOR VERDE**; perfil de consultas de producción pendiente. |
| **BR-008** | Ancla a Estado operativo con Turbo desactivado para navegación interna; prueba Chrome previa validó fragmentos y desbordamiento móvil. | P3 histórico | **VERIFICADO EN CI FOCALIZADO**; revisión manual accesible pendiente. |

### Evidencia reproducible y dictamen

- **Últimas ejecuciones especializadas verdes conocidas:** [42562487952](https://github.com/AliRodri1992/sales_point/actions/runs/42562487952) en `7299330` (**130 ejemplos, 0 fallos**, RuboCop aprobado) y [42562604504](https://github.com/AliRodri1992/sales_point/actions/runs/42562604504) en `281cab1` (ambos jobs aprobados). No son pruebas ejecutadas en el SHA inicial de esta reauditoría.
- **Fallo especializado posterior:** [42562766963](https://github.com/AliRodri1992/sales_point/actions/runs/42562766963) en `c03d7db`; fase **Prepare test database**, antes de RSpec, por fecha futura de migración de Roles. No debe presentarse como «130 tests fallidos» ni como defecto funcional de Sucursales.
- **Diff inspeccionado entre `7299330` y `72d1ff14`:** sin cambios adicionales en controladores, vistas o servicios propios de Sucursales; sí hay cambios compartidos en `UserRole`, `OrganizationMembership`, `Phone`, `Note`, documentos y workflow. Hace falta repetir los contratos de Sucursales cuando la BD pueda prepararse.
- **Pruebas aún no ejecutadas manualmente:** lector de pantalla real, zoom 200 %, contraste visual, foco de formularios 422 y comprobación visual contextual de panel operativo en escritorio/móvil. No se inventan capturas o resultados.
- **CI global:** no aprobado para el SHA de inicio; cancelaciones repetidas por commits paralelos tampoco equivalen a aprobación.
- **Dictamen:** **AUDITADO POR CÓDIGO Y EVIDENCIA CI; NO CERRADO.** Dos mejoras propias identificadas bajo los IDs BR-001 (P2) y BR-003 (P3), y un bloqueo de aceptación externo BR-005. No se realizan cambios funcionales en esta ronda. Sin merge ni aceptación independiente.


### Actualización de frontera de Roles y verificación del estándar ARIA — 2026-11-08

1. **BR-001 P2 (detalle confirmado y norma):** conforme a [ARIA in HTML, recomendación W3C del 11 de agosto de 2026](https://www.w3.org/TR/html-aria/#el-h1-h6), `h1`–`h6` tienen rol implícito `heading`, y `status` **no figura entre los roles permitidos** para estos elementos. `h2[role="status"]` en `_list.html.erb` es una combinación no conforme. Propuesta: conservar `h2` y ubicar `role=status` en un `output`/`div` independiente y persistente; comprobar el anuncio de actualización con lector de pantalla, no solo inspección DOM.
2. **BR-005 (bloqueo externo, cronología):** el archivo original `20261111000000_scope_user_roles_by_organization.rb` causó `InvalidMigrationTimestampError` en [Branches CI 42562766963](https://github.com/AliRodri1992/sales_point/actions/runs/42562766963); se **renombró** después a `20261110040000_scope_user_roles_by_organization.rb`. La nueva ejecución [Branches CI 42563575639](https://github.com/AliRodri1992/sales_point/actions/runs/42563575639), SHA `2a809813`, confirmó fecha superada pero encontró **otro** error previo a RSpec: `PG::DatatypeMismatch`, SQL `INSERT INTO user_roles ... deleted_at` con `NULL` inferido como texto. El commit concurrente `3ea4db5` reemplazó ese literal por `NULL::timestamp`. **Ambas modificaciones de migración están presentes en la rama consultada; todavía no se ha demostrado Branches CI verde en un SHA posterior.** Su dueño sigue siendo Roles, no Sucursales.
3. **Límites:** no se modificó código funcional de Sucursales ni migraciones ajenas durante esta auditoría. La semántica accesible BR-001 y el control de entrada BR-003 continúan abiertos; CI y revisión independiente siguen pendientes. Los logs antiguos continúan como evidencia histórica, no como el estado actual de la rama.


## Corrección BR-001 y BR-003 — 2026-11-08

**Tipo:** implementación focalizada en `feature/fixes`. **Estado:** CAMBIO PREPARADO/PUBLICADO; **verificación independiente y CI del SHA final pendientes**.

- **BR-001 / semántica accesible de resultados:** `_list.html.erb` recupera `h2#branches-result-title` con rol implícito `heading`. `index.html.erb` crea una región de estado `#branch-results-announcement` persistente **fuera** de `turbo-frame#branches_list`, invisible visualmente pero accesible. `index.turbo_stream.erb` actualiza el anuncio en cada filtro AJAX con el recuento real del servidor, sin acoplarlo a sustituciones del encabezado. Se amplían specs de request/Chrome: semántica, recuento actualizado, mensaje de estado y preservación de foco. **Se necesita comprobación con lector de pantalla real** antes de certificar accesibilidad manual.
- **BR-003 / motivo de cambio de estado:** `show.html.erb` sustituye el campo de una sola línea por `textarea` de cuatro filas y tamaño adaptable, conserva el máximo de 2,000 caracteres y las validaciones en servidor, `aria-invalid` y mensaje debajo del campo. Pruebas de request cubren re-render de 422 con 2,001 caracteres y error por campo; Chrome cubre edición del motivo en viewport de 390 px.
- **BR-005 / base de datos y aceptación:** los ajustes son de vista y specs, no requieren migraciones ni recreación de base de datos. Las migraciones de Roles anteriormente bloqueantes ya fueron corregidas por su propio módulo; únicamente verificar migración limpia y CI del SHA final. No modificar datos reales ni ampliar el alcance a otros módulos.
- **Criterio de cierre:** Branches CI (RuboCop focalizado + specs Rails y navegador) verde para el SHA publicado; CI global verde y accesibilidad manual/zoom 200 % para cierre modular conforme al estándar. **No se ha efectuado merge.**


### BR-005 — corrección de puerta de migraciones (dependencia externa)

Durante la verificación del SHA `dd94f85921e75675ecac5e5a90fdb9f9f580b746`, Branches CI [42564627022](https://github.com/AliRodri1992/sales_point/actions/runs/42564627022) aprobó el RuboCop focalizado, pero el RSpec se detuvo antes de ejecutarse por `ActiveRecord::InvalidMigrationTimestampError` del archivo **externo** `20261112010000_add_source_to_role_permission_audit_events.rb` (Roles). Como reparación estrictamente necesaria para completar la verificación modular, se renombra a `20261110041000_add_source_to_role_permission_audit_events.rb` (marca temporal válida, posterior a `20261110040000_scope_user_roles_by_organization.rb` y sin colisión con otros archivos de migración). El cuerpo SQL se conserva exactamente; **no se borran tablas ni datos**. Esto no extiende la auditoría a Roles ni implica aceptar su implementación. **Pendiente:** repetir preparación de base limpia y Branches CI después de publicar.


### BR-003 — resultado de regresión y ajuste de lectura HTML

Branches CI [42565000001](https://github.com/AliRodri1992/sales_point/actions/runs/42565000001), sobre `359ec8480afdd0f6d64c32dc38e24afbb5074c66`: RuboCop de Sucursales **PASÓ** y **la base de datos de pruebas se preparó correctamente**, pero RSpec finalizó **132 ejemplos / 1 fallo**. El único fallo fue una comparación excesivamente literal de `textarea.text`: ActionView agrega un salto de línea al inicio de los contenidos renderizados de `textarea` y Nokogiri lo conserva en `.text`. Se actualiza el spec para comparar el valor tras retirar únicamente ese salto de línea HTML. Las demás 131 pruebas, incluida la nueva validación Chrome, pasaron en esa ejecución. **Aún requiere un nuevo CI especializado verde para marcar BR-003 verificado.** No se modifican reglas de negocio ni validaciones del servidor.


### BR-005 — reinicio seguro de la base exclusiva de CI (2026-11-08)

En Branches CI [42565321011](https://github.com/AliRodri1992/sales_point/actions/runs/42565321011), SHA `db06e4b`, el job se detuvo antes de RSpec con `PG::DuplicateObject` en la clave foránea `user_roles`. El servicio de PostgreSQL de Actions ya crea `sale_point_test` y el workflow repetía `db:create db:migrate`. Se cambia únicamente el paso **Prepare test database** de `.github/workflows/branches-ci.yml` a `db:drop db:create db:migrate`, siguiendo el procedimiento de base limpia del CI global. **Alcance destructor limitado a la base efímera sale_point_test del runner CI**, sin tocar desarrollo/producción ni datos reales. **Estado de la nueva ejecución: pendiente**, no se presume corregida la causa sin resultado verde.


## Verificación automatizada de BR-001, BR-003 y preparación CI — 2026-11-08

**SHA validado:** `b865c461b7aa3c5e8e33c053bbdb6ee90cd1a921` — [Branches CI 42565579713](https://github.com/AliRodri1992/sales_point/actions/runs/42565579713). Resultado comprobado en los jobs reales de GitHub Actions:

| Job | Resultado |
|---|---|
| Branches module RuboCop | **PASÓ** |
| Prepare test database (PostgreSQL efímero; `db:drop db:create db:migrate`) | **PASÓ** |
| Branches models, requests and real browser flows | **PASÓ: 132 ejemplos, 0 fallos** (seed `25971`) |

- **BR-001:** semántica `h2` restaurada y región independiente `role="status"`, `aria-live="polite"`, `aria-atomic="true"` actualizada por Turbo Stream. Prueba real de Chrome y requests **VERIFICADAS AUTOMÁTICAMENTE** en el SHA indicado. Evaluación perceptiva con lector de pantalla real aún pendiente para cierre accesible.
- **BR-003:** motivo de transición multilineal, ajustable en móvil, con máximo de 2,000 caracteres, 422 y error por campo. Pruebas de requests y Chrome **VERIFICADAS AUTOMÁTICAMENTE** en el SHA indicado. La corrección de la prueba de `textarea` retira el salto de línea inicial añadido por ActionView al renderizar HTML, sin modificar la entrada del usuario.
- **BR-005:** bloqueo por migración con fecha futura corregido mediante renombrado mínimo; base efímera del runner recreada correctamente en CI. **La aceptación integral continúa ABIERTA**: el job `CI` general del mismo SHA se canceló por commits paralelos, no constituye éxito global. La documentación y las pruebas no sustituyen revisión manual del lector de pantalla, zoom 200 % y aceptación independiente.
- **Alcance:** ningún dato de bases persistentes eliminado, ninguna fusión realizada. Los IDs históricos se conservan; no duplicar hallazgos en auditorías posteriores.


## Reauditoría AI Dev Suite — Sucursales — 2026-11-09 (SHA d414ec7d)

**Alcance:** rutas y acciones propias de `/admin/branches` (listado, filtros, alta/edición, detalle, estado operativo, terminales embebidas, historial, selección de sucursal y permisos). Contratos externos revisados solo desde Sucursales: `Terminal`, `UserRole`, membresías y controles de inventario/compras como bloqueos de transición. **Método:** procedimientos AI Dev Suite `impeccable-audit`, `ui-ux-pro-max` y `ponytail-engineering`; inspección del código de GitHub, comparación de cambios y resultados de Actions. **No** se ejecutó el CLI externo de los proyectos citados por las habilidades ni hubo sesión de navegador local o pruebas manuales con lector de pantalla.

**SHA base de auditoría:** `d414ec7d6380dd75675836c05b501391c010365f`. Las correcciones funcionales anteriores siguen en el código de este SHA. Desde `7c34a82370c51d80b99daaf031ade51e82e767fc` (último Branches CI verde) hasta el SHA de revisión no hubo cambios en archivos propios de Sucursales; sí hubo cambios en el esquema, migraciones y pruebas de otros módulos.

### Resultado por hallazgo histórico

| ID | Revisión en esta ronda | Estado |
|---|---|---|
| **BR-001** | `h2#branches-result-title` conserva rol de encabezado; región `#branch-results-announcement[role=status][aria-live=polite]` permanece fuera del Turbo Frame y se actualiza por Stream; reintento y foco de filtros cubiertos por Chrome anterior. | **VERIFICADO AUTOMÁTICAMENTE EN SHA ANTERIOR**; pendiente comprobación perceptiva con lector de pantalla. No reabrir por el problema corregido. |
| **BR-002** | `BranchForm`, `Branch`, `_form`, validaciones Rails por campo, asteriscos, `novalidate`, código autogenerado, dirección por país, errores 422 y permisos. Sin defecto nuevo demostrado por esta revisión estática. | Regresiones previas verdes; exploración manual pendiente. |
| **BR-003** | Estado operativo separado, selector/bloqueos, `textarea` de 4 filas para motivo con máximo de 2,000 y error por campo, historial de transiciones. | Regresiones previas verdes; zoom 200 %, voz y revisión visual manual pendientes. |
| **BR-004** | Historial de baja de teléfonos/notas, consulta protegida por `manage?` y restricciones de soft delete. | Regresiones previas verdes; no detectada regresión nueva de este contrato. |
| **BR-005** | [Branches CI 42565873539](https://github.com/AliRodri1992/sales_point/actions/runs/42565873539) aprobó **132 ejemplos / 0 fallos** y RuboCop focalizado para `7c34a82`. En el SHA de auditoría, el job global `Fresh migrations and seed data`, `Rails I18n and YAML audit` y `Security scans` aprobaron; `RuboCop` global **falló con 32 ofensas**, sin ofensas listadas de archivos propios de Sucursales, y `RSpec` fue cancelado por nuevos commits mientras corría. | **ABIERTO**, falta CI global verde para un SHA de aceptación y revisión independiente. |
| **BR-006** | RuboCop focalizado aprobado en último Branches CI y sin ofensas detectadas en archivos propios del módulo en el log global consultado. | Verificado focalmente, no sustituye BR-005. |
| **BR-007** | `Admin::BranchDetail` reutiliza requisitos por estado y conserva regresiones anteriores. Sin perfil SQL de la vista bajo carga representativa. | Implementado y probado anteriormente; medición de carga pendiente. |
| **BR-008** | Ancla de Estado operativo y navegación de secciones siguen presentes con `data-turbo=false`; Chrome anterior verificó navegación y viewport móvil. | Verificado focalmente; revisión manual de zoom/teclado pendiente. |

### Nuevos hallazgos de la ronda

**BR-009 · P1 · Confirmado por inspección de código · Integridad de terminales embebidas · ABIERTO.**

- **Evidencia:** `app/views/admin/branches/_terminal_management.html.erb` usa `@branch.terminals.exists?` y `@branch.terminals.order(:id).each`; `Admin::BranchDetail#load_branch_detail` emplea `@branch.terminals.count`; `Admin::BranchTerminals#change_terminal` obtiene el registro con `@branch.terminals.find(params[:terminal_id])`, todos **sin `where(deleted_at: nil)`**. `app/models/terminal.rb` dispone de `deleted_at` y `active_records`, pero **no aplica default_scope de vigencia**.
- **Riesgo reproducible:** una terminal retirada mediante soft delete sigue incluida en listado y contador; un administrador puede enviar su ID a la ruta de cambio de estado y alcanzar `update!(status:)`. Se detecta por el código, **no se ha ejecutado una petición de regresión específica ni probado su comportamiento de extremo a extremo**.
- **Esperado:** únicamente terminales vigentes en listado y recuentos y ninguna mutación de terminal retirada; la consulta de auditoría/historial sí conserva retiradas.
- **Causa raíz:** falta una relación de terminales vigentes aplicada de forma uniforme en superficie y endpoint.
- **Responsable:** Sucursales, terminales **embebidas**. **Prueba exigida:** crear una terminal, marcar `deleted_at`, comprobar que no aparece en detalle ni contador, probar `PATCH change_terminal` con ID retirado y verificar rechazo, sin modificar registro ni historial; incluir un control positivo para terminal vigente.

**BR-010 · P2 (riesgo de escalabilidad; impacto real por medir) · Patrón de consultas confirmado por código · ABIERTO.**

- **Evidencia:** `Admin::BranchTerminals#next_branch_terminal_code` inicia en 1 y realiza `@branch.terminals.with_deleted.exists?(code: format('POS-%03d', number))` por cada código ocupado hasta encontrar uno disponible. En el caso de los primeros N códigos ocupados, requiere **N+1 comprobaciones SQL** en lugar de una operación de consulta acotada.
- **Impacto:** posibles tiempos crecientes para agregar terminales en sucursales con muchos códigos históricos. La complejidad está confirmada en fuente; **no se midió una degradación real de latencia**.
- **Esperado:** generación de códigos que respete la unicidad histórica sin una consulta por número y conserve la seguridad ante concurrencia bajo bloqueo de sucursal.
- **Prueba exigida:** crear suficientes terminales con códigos consecutivos (incluidas retiradas), contar consultas al alta y exigir un presupuesto constante o acotado, además de asegurar código único y sin reutilización histórica.

### Puertas de calidad y limitaciones

- **Evidencia exitosa verificable:** [Branches CI 42565873539](https://github.com/AliRodri1992/sales_point/actions/runs/42565873539), SHA `7c34a82`: RuboCop focalizado **PASÓ**, `Prepare test database` **PASÓ**, RSpec + Chrome **132 pruebas, 0 fallos**. No afirmar que las nuevas pruebas BR-009/BR-010 ya corrieron.
- **Global SHA d414ec7d:** [CI 42609077039](https://github.com/AliRodri1992/sales_point/actions/runs/42609077039): migraciones/semillas, seguridad e i18n **PASARON**; RuboCop global **32 ofensas**; RSpec **CANCELADO**. Fallas externas no son defectos de Sucursales, pero bloquean cierre del módulo conforme al estándar.
- **Sin evidencia manual:** revisión visual a 200 % de zoom, lector de pantalla real, contraste y teclado en entorno local. Los anteriores tests de navegador son evidencia real automatizada, no auditoría perceptiva manual.
- **Dictamen:** **AUDITADO / NO CERRADO**. Hallazgos abiertos propios BR-009 (P1) y BR-010 (P2); BR-005 continúa abierto por falta de CI global verde y aceptación independiente. **No se modificó código funcional** en esta reauditoría. Sin merge.


## Adecuaciones BR-009 y BR-010 — 2026-11-09

**Rama:** `feature/fixes`. **Estado inicial:** IMPLEMENTADO, PENDIENTE VERIFICACIÓN EN CI; preservar el resultado histórico de las auditorías anteriores.

- **BR-009 (P1):** `Terminal.not_deleted` centraliza el estado vigente sin imponer `default_scope`, por lo que `with_deleted` conserva intacto el historial. `Admin::BranchDetail` cuenta solo terminales vigentes; `_terminal_management` muestra únicamente esas terminales con una sola consulta, incluidos los botones de estado. `Admin::BranchTerminals#update_branch_terminal!` busca la terminal vigente **dentro del bloqueo de la sucursal**, de modo que un ID retirado genera 404 y no alcanza `update!`. Contratos de cierre y auditoría sin cambios.
- **BR-010 (P2):** el siguiente código `POS-%03d` se determina con una agregación `MAX(SUBSTRING(code FROM 5)::numeric)` en PostgreSQL restringida a códigos `POS-` numéricos de la misma sucursal e incluyendo las terminales retiradas. El algoritmo pasa de N+1 consultas por consecutivo ocupado a **una consulta agregada**; conserva el bloqueo de sucursal que serializa altas concurrentes y no reutiliza un código retirado.
- **Regresiones nuevas:** requests verifican contador/listado, rechazo 404 de IDs retirados, unicidad histórica con 20 consecutivos y códigos de otra sucursal, además de presupuesto de consultas. Model spec comprueba vigencia/consulta histórica. Chrome comprueba ocultación visual y disponibilidad de acciones vigentes. Branches CI incorpora `Terminal` y su spec a los disparadores, RuboCop y RSpec.
- **No se alteraron** permisos, estados permitidos, esquema PostgreSQL, migraciones o registros reales. Sin merge. Para cierre técnico, Branches CI debe ser verde en el commit de implementación; BR-005 global y auditoría manual de accesibilidad son controles separados.


## Cierre de adecuaciones BR-009 y BR-010 — evidencia de GitHub Actions (2026-11-09)

**Verificación confirmada:** SHA `aa1f38dc6e455a4452b688609dc496635ed31075`, [Branches CI 42613502646](https://github.com/AliRodri1992/sales_point/actions/runs/42613502646). Ambos jobs **APROBADOS**: `Branches module RuboCop` y `Branches models, requests and real browser flows` (**153 ejemplos, 0 fallos**, seed `57662`). La preparación de PostgreSQL de pruebas también pasó.

- **BR-009 — IMPLEMENTADO Y VERIFICADO AUTOMÁTICAMENTE:** ámbito `Terminal.not_deleted` sin `default_scope`; solo terminales vigentes en recuento, listado y botones de `/admin/branches/:id`; el cambio de estado busca el ID vigente **dentro del bloqueo de sucursal**, deniega el ID retirado mediante 404 y preserva el estado. Se agregaron pruebas de request, modelo y navegador; el acceso histórico mediante `with_deleted` se conserva.
- **BR-010 — IMPLEMENTADO Y VERIFICADO AUTOMÁTICAMENTE:** el código automático `POS-%03d` usa una agregación SQL para obtener el máximo numérico de la sucursal, incluyendo bajas históricas. La creación permanece bajo `branch.with_lock` para concurrencia. Regresión con **20 códigos ocupados** y uno retirado, otra sucursal con código alto, validación de no reutilización y presupuesto acotado de consultas.
- **Regresiones preexistentes:** se repararon exclusivamente fixtures de prueba para evitar nombres duplicados de sucursal y asignaciones de rol a una organización distinta, conforme a las restricciones vigentes; **no** se relajaron reglas de autorización o validación. El modelo `Terminal` y su spec ahora forman parte del control focalizado.
- **BR-005 — PERMANECE ABIERTO:** CI global del SHA verificado **cancelado** por cambios concurrentes; no existe certificación global verde en el mismo SHA. Tampoco se efectuó auditoría perceptiva manual con lector de pantalla y zoom 200 %, ni una aceptación independiente.
- **Base de datos:** no se modificó el esquema, no se recreó una base persistente ni se borraron datos. Solo se usó la base efímera propia del runner CI. **Sin merge**.

**Dictamen:** `BR-009` y `BR-010` cerrados a nivel de **implementación y regresión automatizada**. La aceptación integral del módulo depende de `BR-005` y de la inspección manual pendiente. Las auditorías posteriores deben conservar estos IDs y distinguir las limitaciones de aceptación de nuevos defectos reales.
