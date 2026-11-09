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
