# Registro de calidad — Roles y permisos

**Módulo y ruta principal:** Roles y permisos — `/system_roles`  
**Estado:** REAUDITADO 2026-11-09 · CI FOCALIZADO VERDE · 001 REABIERTO · 011–013 NUEVOS · NO CERRADO.  
**Fecha de auditoría:** 2026-11-09 (America/Mexico_City).  
**Rama:** `feature/fixes`. **SHA de partida/auditado:** `d414ec7d6380dd75675836c05b501391c010365f`.  
**SHA de aceptación:** PENDIENTE. **Responsable/revisor independiente:** PENDIENTE.  
**Método:** AI Dev Suite — Ponytail Engineering, Impeccable, UI UX Pro Max. Inspección real de código por GitHub; no se ejecutó el detector CLI de terceros.

> Este registro es la fuente de verdad de hallazgos del módulo. Lo observado en el código se distingue de las hipótesis y de pruebas pendientes. Un commit documental no equivale a una corrección ni al cierre de la auditoría. Conserva los IDs entre siguientes iteraciones.

## Reauditoría de Roles y Permisos — 2026-11-09 · AI Dev Suite

**Línea base:** `feature/fixes` SHA `d414ec7d6380dd75675836c05b501391c010365f` (código consultado en GitHub). **Método:** guía AI Dev Suite (Ponytail Engineering, Impeccable y UI UX Pro Max), comparación con el último expediente, examen de políticas, resolutores de permisos, rutas reales, servicios de transición, auditoría, componentes Stimulus/ERB y CI. **Alcance delimitado:** `/system_roles`, `SystemRoleStatusesController` y dependencias imprescindibles de acceso de Usuarios/organizaciones y catálogos. No se usó ningún CLI independiente de terceros ni un navegador conectado a localhost. **Esta sección prevalece sobre la declaración histórica de implementación anterior sin borrar sus evidencias.**

### Baseline de CI de esta nueva iteración

- **System Roles CI — verde en SHA `d414ec7`:** [ejecución 42609077100](https://github.com/AliRodri1992/sales_point/actions/runs/42609077100). RuboCop específico aprobado; base de datos desde migraciones aprobada; 115 ejemplos de roles/políticas/requests/servicios/navegador, 0 fallos; 3 ejemplos de repetibilidad de semillas, 0 fallos. **118 pruebas focalizadas aprobadas.**
- **CI general — sin cierre:** [ejecución 42609077039](https://github.com/AliRodri1992/sales_point/actions/runs/42609077039). Migraciones y semillas, análisis de seguridad y traducciones aprobaron; RuboCop global falló con 32 ofensas en archivos no propios de Roles (Inventario, Onboarding, routes y scripts entre otros); job RSpec cancelado por avance concurrente de rama. No afirmar CI global verde.
- **Comparativa desde la anterior auditoría (`3c562ae`) hasta `d414ec7`:** solo se modificaron `db/schema.rb` y la migración de nombre `20261110010100`, aparte de retirar un archivo `.bak` de esquema; no hay cambios de lógica del módulo. Las verificaciones previas sobre 001–010 permanecen válidas **para los escenarios que cubren**, pero la cobertura no garantiza ausencia de defectos diferentes.

### Hallazgos abiertos y nueva evidencia

| ID | Prioridad y estatus | Evidencia y riesgo | Prueba/adecuación que debe exigirse |
|---|---|---|---|
| **SYSTEM_ROLES-001** (reabierto, **no duplicado**) | **P1 · FRONTERA MULTIEMPRESA NO RESUELTA** | La política exige `super_admin` válido en la organización seleccionada, pero `SystemRolesController#set_system_role` obtiene un `SystemRole` global sin organización; las asociaciones `SystemRolePermission` también son globales y `UserEffectiveRoles` consume ese mismo rol en cualquier organización con asignación. **Por arquitectura**, un superadministrador habilitado solo en organización A puede editar permisos de un rol compartido y alterar el acceso de usuarios de organización B. Queda pendiente aclarar si `super_admin` representa administrador de plataforma o solo de una empresa. | Prueba de integración multiempresa: A/B, mismo rol compartido, superadmin exclusivamente en A, operación PATCH desde A, verificar acceso de B antes/después. Si la gestión de roles es de plataforma, exigir identidad/privilegio de plataforma explícito; si es por empresa, aislar definiciones/asignaciones o permisos por organización. **No debilitar las políticas actuales.** |
| **SYSTEM_ROLES-011** (nuevo) | **P1 · HIPÓTESIS DE AUTORIZACIÓN SIN TENANT, PENDIENTE DE REPRODUCCIÓN** | `User#admin?` cuando `CurrentOrganizationAccess.organization` es `nil` consulta `user_roles.active` sin filtro de membresía; `UserEffectiveRoles#effective_role_assignments(organization: nil)` también omite comprobar membresías accesibles. `ApplicationController#enforce_active_account` comprueba estado de cuenta/sesión, no `organization_accessible?`; `CatalogPolicy` autoriza catálogos por `user.admin?` o permisos. Algunos controladores como `Admin::LanguagesController` y `Admin::CategoriesController` no tienen guardia propia que exija organización. **No se ha probado que Devise/Warden permita realmente la sesión bajo esta precondición**, por lo que no se afirma explotación. | Request con sesión existente, cuenta activa y rol previo, después suspensión/revocación de la última membresía, intentar `GET`/`POST` de catálogos y consultar `User#permission?` sin tenant. Denegar permisos ante ausencia de organización accesible o imponer identidad de plataforma diseñada expresamente; añadir cobertura de revocación de sesión. |
| **SYSTEM_ROLES-012** (nuevo) | **P2 · CONFIRMADO EN LÓGICA POR INSPECCIÓN, FALTA PRUEBA DINÁMICA** | `SystemRoles::StatusReview` firma `StatusImpact#fingerprint`, pero ese fingerprint incluye asignaciones de otros roles y estados de sucursales, **no incluye permisos activos de roles alternativos ni el estado de membresías**. Cambiar permisos de otro rol o suspender su membresía puede variar `without_other_roles` sin invalidar el token previamente emitido. El cambio de estado puede confirmarse con una revisión de impacto desactualizada aunque se recalcule al guardar. | Crear token para desactivar rol A con alternativa efectiva B, retirar el permiso de B (o suspender membresía), verificar que el token anterior sea rechazado y se exija revisar el nuevo impacto. Incluir datos que afectan el impacto en fingerprint o usar versión/epoch de autorizaciones. |
| **SYSTEM_ROLES-013** (nuevo) | **P2 · UX OBSERVADA EN CÓDIGO, PENDIENTE DE NAVEGADOR** | `role_permissions_controller.js#selectGroup` modifica solo filas visibles, pero `#refresh` marca `*.access` como dependencia incluso si su fila está oculta por la búsqueda. Así el rótulo **«Seleccionar visibles»** puede ocultar cambios automáticos en otros permisos; las pruebas con `suppliers.contacts.*` no ejercitan dependencias `languages/products/customers/users/categories`. La autoselección es necesaria para consistencia, pero requiere transparencia. | Prueba JS/browser: filtrar `languages.update` mientras `languages.access` queda oculto; seleccionar visibles; verificar autoasignación, contador, aviso accesible sobre dependencias añadidas, y persistencia; no permitir guardar un estado inválido o silencioso. |

### Conservados de la última auditoría

**SYSTEM_ROLES-002 a 010:** implementaciones existentes sin regresión demostrada en los 118 tests de la línea base. No se reabren por simple sospecha. **SYSTEM_ROLES-005/006** conservan pendiente revisión manual (teclado, lector de pantalla, zoom 200%, responsive e idiomas); **SYSTEM_ROLES-007** conserva pendiente validación de duplicados reales e índice de nombres sobre **BD histórica**. La nueva consulta sobre roles compartidos **reabre 001** porque su remedio previo limitó al actor pero no determinó inequívocamente el ámbito multiempresa.

### Puerta de salida y prohibiciones

1. Resolver diseño de privilegio global frente a organización, con aceptación explícita de negocio antes de modificar alcance de roles; probar multiempresa.
2. Añadir regresiones negativas de sesión sin tenant y token de revisión obsoleto; aplicar corrección mínima tras reproducir. Refinar UX de la selección filtrada y ejecutar navegador real.
3. Revalidar todos los 118 tests focalizados, migraciones, I18n, auditoría de seguridad y CI general en el mismo SHA. Respetar archivos de otros módulos y pushes simultáneos.
4. **NO CERRAR**, **NO FUSIONAR** hasta CI global verde, revisión manual de accesibilidad y aceptación independiente.

**Esta reauditoría es diagnóstica:** no se cambió código aplicativo ni se ejecutó una base de datos productiva. El expediente documenta la diferencia entre evidencia comprobada por lectura, hipótesis que requieren prueba y validaciones CI verdaderamente realizadas.

---

## Adecuaciones y validación focalizada — 2026-11-08 (AI Dev Suite)

**Estado posterior a la reauditoría:** los hallazgos reabiertos, incompletos y nuevos se corrigieron con cambios publicados en `feature/fixes`. **Evidencia de CI focalizado VERDE:** `adfba90cbb132f3171e8f1db1524fb118b9b39b5`, workflow [System Roles CI, ejecución 42566031210](https://github.com/AliRodri1992/sales_point/actions/runs/42566031210). Esta actualización **prevalece** sobre el estado histórico de cada ID documentado a continuación; no se eliminaron hallazgos ni se emitió cierre definitivo.

| ID | Estado de implementación y verificación | Evidencia técnica |
|---|---|---|
| SYSTEM_ROLES-001 (P1) | **CORREGIDO · VERIFICADO EN CI FOCALIZADO** | `SystemRolePolicy` exige rol superadministrador asignado dentro de una membresía organizacional accesible. Se adaptaron actores de request, service y seed repeatability, sin degradar autorización. Los tests de transición y repetibilidad pasaron. |
| SYSTEM_ROLES-002 (P1) | **CORREGIDO · VERIFICADO EN CI FOCALIZADO** | `AdministratorPermissionProvisioner` añade auditorías `source: system`, `actor_id: nil` dentro de la misma transacción de alta; migración `20261112010000` con check de coherencia actor/origen. `SystemRolePermissionAuditEvent` y vista de historial muestran «Sistema» en es/en/ko. Se probaron provisión, inmutabilidad del origen e idempotencia. |
| SYSTEM_ROLES-003 (P1) | **CORREGIDO · VERIFICADO EN CI FOCALIZADO** | `PermissionSelection` rechaza acciones dependientes si falta su `*.access` incluso cuando el permiso base se desactivó o no está seleccionado. Requests 422 y transacción sin cambios cubiertos. |
| SYSTEM_ROLES-004 (P1) | **IMPLEMENTADO · VERIFICADO EN NAVEGADOR AUTOMATIZADO** | Selección masiva limitada a filas visibles en Stimulus. Specs Selenium con búsqueda/filtro, selección y persistencia pasaron. |
| SYSTEM_ROLES-005 (P2) | **IMPLEMENTADO · VERIFICACIÓN AUTOMATIZADA PARCIAL** | Validación de modelo con mensajes por campo, `novalidate` y selector Delta POS conservados; navegador automatizado pasó. Falta recorrido visual manual con lector de pantalla, zoom y dispositivos. |
| SYSTEM_ROLES-006 (P2) | **IMPLEMENTADO · VERIFICACIÓN AUTOMATIZADA PARCIAL** | Motivo/confirmación por campo, 422 y token de revisión; requests y navegador automatizados pasaron. Falta revisión manual completa de accesibilidad. |
| SYSTEM_ROLES-007 (P2) | **IMPLEMENTADO · VERIFICADO CON MIGRACIONES NUEVAS** | Normalización de nombre e índice de unicidad, con migración limpia en CI. Pendiente análisis de duplicados en una BD histórica real antes de migrarla. |
| SYSTEM_ROLES-008 (P2) | **CORREGIDO · VERIFICADO EN CI FOCALIZADO** | `StatusImpact` cuenta alternativas solo cuando tienen permisos activos y organización correspondiente con membresía accesible; respeta sucursales operativas. Se prueban sin permisos, tenant cruzado, alternativa válida y sucursal en preparación. |
| SYSTEM_ROLES-009 (P1) | **CORREGIDO · VERIFICADO EN CI FOCALIZADO** | `SystemRolesController#update` no sustituye permisos si solo se envían metadatos, y `PermissionUpdater` conserva asignaciones inactivas aun con edición explícita. Requests verifican asociaciones y diff de auditoría. |
| SYSTEM_ROLES-010 (P1, hipótesis) | **ENDURECIDO · PRUEBA NEGATIVA APROBADA** | Sin membresía organizacional accesible, las rutas de Roles quedan inaccesibles; según el estado de sesión, la cuenta se redirige a inicio de sesión. Pruebas de política cubren además superadministrador de organización A intentando administrar desde B. La hipótesis de acceso residual no se reprodujo tras el endurecimiento. |

### Pruebas ejecutadas realmente

| Control | Estado | Evidencia |
|---|---|---|
| RuboCop **solo del módulo** | **PASS** | Workflow 42566031210, job «Roles module RuboCop» |
| Migración desde base vacía | **PASS** | Workflow 42566031210, paso «Recreate test schema from migrations» |
| Modelos, políticas, servicios, requests y navegador Chrome/Selenium | **PASS — 115 ejemplos, 0 fallos** | Workflow 42566031210, job «Roles requests, policies, services and real browser flows» |
| Repetibilidad de semillas (seguridad y cambios manuales) | **PASS — 3 ejemplos, 0 fallos** | Mismo job, paso «Verify seed repeatability after superadmin policy change» |
| **Total pruebas focalizadas** | **118 ejemplos, 0 fallos** | SHA `adfba90c` |
| CI global del repositorio | **NO VERDE / NO ACEPTADO** | Sigue bloqueado por controles ajenos a Roles, incluidos RuboCop de módulos externos y ejecuciones canceladas por pushes concurrentes. No sustituir el CI global por este workflow. |
| Accesibilidad manual (teclado, lector de pantalla, zoom 200 %) y aceptación independiente | **PENDIENTE** | No hay navegador local de Delta POS conectado ni revisor externo |

**Historial de correcciones relevantes:** `a76a60a` (políticas, auditoría automática, persistencia, KPI y migración), `0e30fb2` (autorización de lectura en tenant), `5a83143` y `5af1206` (fixtures y regresiones), `41f8557`/ `cb371f1`/ `490b592` (schema sincronizado), `e20daba` (refactor sin ofensas propias), `7d2452a` (workflow dedicado), `ba2aaa0`/ `adfba90` (validaciones y sincronización de specs).

**Límites y decisión de cierre:** no se alteraron las pantallas internas de Usuarios ni de Sucursales; solo se modificaron contratos directos y pruebas de integración. No se fusionaron ramas. Aunque **los arreglos del módulo están implementados y su CI focalizado está verde**, el expediente conserva el estado **NO CERRADO** mientras falte CI global verde, revisión manual de accesibilidad, validación sobre BD histórica e independencia de la aceptación.

---

## Reauditoría independiente — 2026-11-08 (AI Dev Suite)

**Base:** `feature/fixes` SHA `d7d232239de28132d758b85ca11cd648e9ce7101` (consultado mediante GitHub). **Metodología:** procedimientos Ponytail Engineering, Impeccable y UI UX Pro Max del plugin AI Dev Suite; inspección real de rutas, controlador, política, modelo, servicios, Stimulus, vistas, specs y CI. **No se ejecutaron** los CLIs originales de terceros ni pruebas de navegador local. Esta sección actualiza y prevalece sobre estados anteriores, sin borrar los IDs.

### Matriz de control de reincidencia (los mismos IDs)

| ID | Prioridad | Resultado actual | Evidencia y acción pendiente |
|---|---|---|---|
| SYSTEM_ROLES-001 | P1 | **REABIERTO: regresión de integración confirmada en CI** | `SystemRolePolicy#global_manager?` exige `super_admin`, pero `spec/seeds/full_seed_repeatability_spec.rb:93-104` invoca `StatusTransition` con el usuario sembrado `administrador@delta.com`, y `spec/services/system_roles/status_transition_spec.rb` asigna únicamente `administrator` al actor. CI `42562001050`, job RSpec `128980328080` falló en el primero con `Pundit::NotAuthorizedError`; los specs del servicio son incompatibles por lectura, pero no se ejecutaron en ese job. **Acción:** adecuar fixtures/actor de pruebas a superadministrador autorizado, mantener denegación de administrador ordinario y validar el flujo de seeds sin rebajar la política. |
| SYSTEM_ROLES-002 | P1 | **IMPLEMENTACIÓN PARCIAL** | `SystemRoles::PermissionUpdater` registra diffs del editor, pero `AdministratorPermissionProvisioner.call`/`.call_for_permission` crea `SystemRolePermission` por callbacks automáticos sin evento en `SystemRolePermissionAuditEvent` ni origen/actor técnico. **Acción:** definir y registrar eventos de provisionamiento automático identificados como `system`, sin atribuirlos falsamente a un usuario; probar creación y reactivación de permisos. |
| SYSTEM_ROLES-003 | P1 | **IMPLEMENTACIÓN PARCIAL** | `SystemRoles::PermissionSelection#missing_base_access?` solo evalúa los códigos base recogidos de `Permission.available`. Cuando un `*.access` del catálogo está inactivo/ausente, la dependencia de una acción puede pasar sin comprobarse, aunque el consumidor requiera acceso. **Acción:** contrastar con todas las dependencias declaradas del consumidor y rechazar o resolver explícitamente bases indisponibles; prueba negativa sin JS. |
| SYSTEM_ROLES-004 | P1 | **IMPLEMENTADO POR CÓDIGO, NO VERIFICADO EN NAVEGADOR** | `role_permissions_controller.js#selectGroup` filtra `row.hidden` y las traducciones aclaran «Seleccionar visibles». Probar búsqueda parcial, operación masiva, restablecimiento de filtros y dependencias de base ocultas en navegador real. |
| SYSTEM_ROLES-005 | P2 | **IMPLEMENTADO POR CÓDIGO, NO VERIFICADO EN NAVEGADOR** | `_form.html.erb` muestra errores individuales y asteriscos; formulario `novalidate`, selector propio y `aria-describedby`. Falta prueba real en móvil/escritorio, teclado, invalidaciones de nombre/tipo y retorno 422. |
| SYSTEM_ROLES-006 | P2 | **IMPLEMENTADO POR CÓDIGO, NO VERIFICADO EN NAVEGADOR** | `status_review.html.erb` distingue error en motivo y confirmación; pendiente comprobar expiración y preservación de datos, accesibilidad y mensajes con tres locales. |
| SYSTEM_ROLES-007 | P2 | **IMPLEMENTADO, VERIFICACIÓN PARCIAL** | `SystemRole` normaliza/valida y migración `20261110010100` añade índice `LOWER(BTRIM(name))`. Migración limpia pasó en CI; **pendiente** revisar nombres duplicados preexistentes en actualización de BD real y variantes con espacios internos (no cubiertas por el índice de la misma forma que normaliza el modelo). |
| SYSTEM_ROLES-008 | P2 | **IMPLEMENTACIÓN PARCIAL** | `StatusImpact#effective_other_user_ids` filtra sucursales operativas, pero acepta un rol alternativo sin permisos y no evalúa el alcance de la organización del usuario; puede disminuir indebidamente «Usuarios sin otro rol efectivo». **Acción:** definir KPI exacto, restringir a asignaciones realmente efectivas dentro del ámbito medido y probar tenants cruzados. |

### Hallazgo nuevo de esta iteración

**SYSTEM_ROLES-009 — P1 · CONFIRMADO POR CÓDIGO · Pérdida silenciosa de asociación de permisos inactivos al actualizar solo metadatos.**

- **Archivo/flujo:** `app/controllers/system_roles_controller.rb#update` sustituye `permission_ids` ausentes por `@system_role.permissions.available.ids`; `#save_permissions` invoca `SystemRoles::PermissionUpdater#persist_assignments!`, que borra toda asociación cuyo ID no figure en la selección.
- **Secuencia reproducible requerida:** (1) mantener un rol con un permiso asignado y después inactivar ese permiso; (2) editar solo el nombre o descripción del rol mediante `PATCH /system_roles/:id` sin `permission_ids`; (3) comprobar que desaparece la asociación con el permiso inactivo. Esto puede impedir que vuelva a concederse ese permiso tras su reactivación, aunque no se editó su selección.
- **Esperado:** una operación solo de metadatos no debe cambiar asociaciones de permisos. Separar cambio de metadatos y actualización expresa de permisos, o conservar sin pérdida las asociaciones no seleccionables.
- **Regresión obligatoria:** request de metadatos con permiso inactivo, reactivación posterior y diff de auditoría; comparar antes/después.
- **Propietario:** Roles y Permisos. **Estado:** ABIERTO, sin ejecución de escenario.

### Contrato de organizaciones revisado tras avances simultáneos

Mientras se elaboraba esta reauditoría, `feature/fixes` incorporó `db/migrate/20261111000000_scope_user_roles_by_organization.rb` y cambios en `UserEffectiveRoles`, `UserRole` y `User#admin?` (cambios posteriores al SHA `d7d2322`). Ahora `UserEffectiveRoles#effective_role_assignments` restringe asignaciones a la organización actual **cuando hay organización**. Por ello, la observación 008 sigue siendo relevante: `StatusImpact#effective_other_user_ids` **no** aplica la misma condición de tenant ni valida que el rol alternativo conceda permisos reales. Estos cambios recientes no quedaron cubiertos por el CI histórico de `d7d2322`.

**SYSTEM_ROLES-010 — P1 · HIPÓTESIS DE SEGURIDAD PENDIENTE DE PRUEBA · Gestión de roles sin organización accesible.**

- **Evidencia de código:** `SystemRolesController` solo exige `authenticate_user!`, sin guardia explícita para `current_organization.nil?`; `ApplicationController#current_organization` devuelve `nil` si no existen membresías accesibles; `User#admin?` y `UserEffectiveRoles#role?` con contexto de organización `nil` permiten comprobaciones de asignaciones activas sin filtrar `organization_id`. `User#organization_accessible?` devuelve `true` cuando no existen membresías no eliminadas.
- **Hipótesis y precondiciones:** una cuenta globalmente activa con rol `super_admin` organizacional persistente, pero con todas sus membresías archivadas, podría superar la autorización de `/system_roles` sin organización accesible. No se afirma explotación ni se asume que los flujos normales de baja dejan asignaciones huérfanas; el contrato debe cubrir expresamente la condición.
- **Prueba requerida:** crear una cuenta con rol de superadministrador y membresía en empresa A, retirar la membresía manteniendo la asignación como escenario de datos legados y verificar que `GET /system_roles`, `POST /system_roles` y `PATCH .../permissions` responden 403 cuando `current_organization` es `nil`. Distinguir de superadministración de plataforma explícita si el negocio la permite sin tenant.
- **Corrección sugerida si se reproduce:** denegar la administración de roles globales sin contexto organizacional accesible, salvo identidad de plataforma con privilegio diseñado explícitamente, y endurecer la consulta de roles cuando el tenant no está definido. Propietario del endpoint: Roles y Permisos; contrato de autenticación/membresía: Usuarios.
- **Estado:** HIPÓTESIS, pendiente de reproducir, decisión de negocio y prueba. No contabilizar como fallo confirmado.

### Evidencias objetivas del SHA auditado

| Control | Resultado comprobado | Referencia |
|---|---|---|
| Migraciones desde BD limpia y seeds | **PASS** | https://github.com/AliRodri1992/sales_point/actions/runs/42562001050 |
| Rails I18n / YAML | **PASS** | mismo run, `Rails I18n and YAML audit` |
| Security scans | **PASS** | mismo run, `Security scans` |
| RSpec global | **FAIL**, 5 ejemplos / 1 fallo al validar repetibilidad de seeds; el resto de suites no llegó a ejecutarse | job `128980328080`, `spec/seeds/full_seed_repeatability_spec.rb:87`, error Pundit producido por la nueva política del módulo |
| RuboCop global | **FAIL**, 32 ofensas en archivos de otros módulos y scripts, incluidas 2 fallas de sintaxis en specs de Inventario/Compras | job `128980328039`; no reportó ofensas en archivos de Roles y Permisos |
| Pruebas de UI/UX en navegador real | **NO EJECUTADO** | El navegador conectado solo exponía pestañas de ChatGPT, sin la aplicación Delta POS local ni sesión de prueba |

**Conclusión técnica:** el módulo **NO está cerrado**. Reabrir SYSTEM_ROLES-001; mantener 002, 003 y 008 como incompletos; añadir 009. Las implementaciones 004-007 se conservan **pendientes de evidencia de ejecución**. No cambiar las políticas para hacer pasar fixtures obsoletos. Las ofensas globales de Inventario/Compras/Onboarding permanecen **EXTERNAS** y bloquean cierre global, no constituyen nuevos defectos de `/system_roles`.

**Siguiente puerta obligatoria:** corregir P1 y el contrato de seeds, ejecutar specs focalizados de roles, seed repeatability, accesos multiempresa, navegador y luego CI completo verde en un **único SHA**. No fusionar mientras falle o esté pendiente.

---

## Alcance y rutas propias

| Ruta y acción | Implementación | Autorización y recorrido | Pruebas identificadas |
|---|---|---|---|
| `GET /system_roles` (index) | `SystemRolesController#index`, `views/system_roles/index` | `SystemRolePolicy#index?`; disponibles/archivados, paginación | `spec/requests/system_roles_spec.rb`; `spec/requests/system_roles_editor_spec.rb` |
| `GET /system_roles/new`, `POST /system_roles` | `#new/#create`, `_form`, `_permissions` | `create?`; alta inactiva y selección de permisos | `spec/features/system_roles_spec.rb`; `spec/requests/system_roles_editor_spec.rb` |
| `GET /system_roles/:id`, `GET /system_roles/:id/edit`, `PATCH /system_roles/:id` | `#show/#edit/#update` | `show?`, `update?`; rol protegido en lectura | `spec/requests/system_roles_editor_spec.rb` |
| `PATCH /system_roles/:id/permissions` | `#update_permissions`, `SystemRoles::PermissionSelection`, Stimulus `role_permissions_controller.js` | `update_permissions?`; sustitución de selección | `spec/features/system_roles_editor_browser_spec.rb` |
| `GET /system_roles/:id/status_review`, `PATCH /system_roles/:id/status` | `SystemRoleStatusesController`, `StatusImpact`, `StatusReview`, `StatusTransition` | `change_status?`; token de revisión, motivo e historial | `spec/requests/system_role_statuses_spec.rb`; `spec/features/system_role_statuses_browser_spec.rb` |
| `DELETE /system_roles/:id` | `SystemRolesController#destroy` | No borra: redirige conceptualmente a revisión mediante HTTP 422 | `spec/requests/system_roles_spec.rb` |

**Incluye:** `SystemRole`, `Permission`, `SystemRolePermission`, `SystemRoleStatusEvent`, políticas, formularios, tarjetas, listado, búsqueda, locales es/en/ko, flujo de cambios de estado y reglas directas de permisos.

**Contratos solamente (no auditar módulos vecinos):** Usuarios (`UserRole`, `UserEffectiveRoles`, asignaciones al retirar rol); Sucursales (rol de sucursal operativa e impacto de cambios); autorización en módulos consumidores (por ejemplo `CatalogPolicy`). No modificar sus pantallas internas en esta auditoría.

## Fortalezas comprobadas por lectura de código

- Pundit protege las rutas CRUD y excluye a usuarios no administradores; roles `administrator` y `super_admin` no permiten edición ni cambio de estado desde los endpoints.
- Alta de rol inactiva, rechazo de transición directa y protección contra archivado con asignaciones vigentes.
- Cambios de estado serializados con `with_lock`, token de revisión que caduca y huella de datos; evento con actor, motivo e impacto.
- Selección de IDs comprueba formato y existencia en permisos disponibles; guardado de metadatos y permisos dentro de transacción/bloqueo.
- Hay specs de requests, modelos, políticas y navegador que cubren parte de estas rutas; su existencia NO acredita una ejecución satisfactoria.
- Listado y editor incluyen paginación, búsqueda, grupos, etiquetas accesibles y estilos responsive; pendiente prueba visual real.

## Registro único de hallazgos

### SYSTEM_ROLES-001 — P1 · PROPIO · Política de privilegios globales sin diferenciación explícita

- **Tipo de evidencia:** confirmado por lectura del alcance del permiso; impacto multiempresa **por validar según definición de negocio**.  
- **Ubicación:** `app/policies/system_role_policy.rb` (usa `user.admin?` en index/show/create/update/change_status); `app/models/user.rb#admin?`; `app/services/system_roles/status_impact.rb`; `config/locales/system_role_lifecycle.es.yml` (documenta efecto entre organizaciones).
- **Situación:** los roles y sus permisos están compartidos globalmente. Cualquier cuenta con rol administrativo activo puede cambiar configuraciones que afectan a usuarios en distintas organizaciones. Debe determinarse formalmente si un administrador de organización puede gobernar un catálogo de roles global o si esta facultad pertenece solo a `super_admin`/operador de plataforma.
- **Causa raíz:** autorización basada en admin genérico, sin distinción de propiedad global/de organización en el recurso.
- **Acción:** definir matriz de responsabilidad; si la intención es aislamiento tenant, separar roles por organización o restringir gestión global al superadministrador (sin alterar otras políticas indiscriminadamente).
- **Regresión:** administrador de una organización intenta modificar/retirar rol con asignaciones ajenas; superadministrador permitido; ninguna lectura de datos ajenos no autorizados.
- **Estado:** IMPLEMENTADO SIN VERIFICAR — decisión de seguridad y prueba de integración pendientes.

### SYSTEM_ROLES-002 — P1 · PROPIO · Sin auditoría durable de altas/bajas de permisos

- **Evidencia:** `SystemRolesController#replace_permissions` borra/crea asociaciones y solo emite `SystemRoleNotification` al actor. `SystemRoleStatusEvent` audita transiciones de estado, no el diff de permisos concedidos/revocados.
- **Riesgo:** no existe un historial propio, consultable e inmutable para reconstruir quién cambió qué permiso y cuándo; especialmente relevante para privilegios sensibles.
- **Acción:** evento de auditoría estructurado y append-only con actor, rol, permisos añadidos/revocados y contexto; escribir en la misma transacción que el cambio y presentar historial con autorización.
- **Regresión:** comparar evento antes/después, fallo transaccional, cambios concurrentes, protección de roles administrativos.
- **Estado:** IMPLEMENTADO SIN VERIFICAR — confirmado por código; no reproducido en ejecución.

### SYSTEM_ROLES-003 — P1 · PROPIO/CONTRATO · Dependencias `*.access` solo aplicadas por JavaScript

- **Evidencia:** `app/javascript/controllers/role_permissions_controller.js#refresh` activa `prefix.access` al seleccionar una acción de `languages/products/customers/users/categories`. `SystemRoles::PermissionSelection#valid?` valida únicamente IDs activos y no verifica esas dependencias. `CatalogPolicy#permitted_action?` exige ambos permisos.
- **Reproducción requerida:** enviar `PATCH /system_roles/:id/permissions` con `languages.update` pero sin `languages.access`; el controlador acepta la selección, mientras que la política no habilita la operación al usuario asignado.
- **Riesgo:** diferencias entre permisos guardados, opciones visibles y acceso efectivo. También puede surgir desmarcando manualmente `*.access` después de seleccionar una acción.
- **Acción:** decidir explícitamente entre autocompletar o rechazar con error contextual en servidor. Alinear el editor y las pruebas para todas las dependencias reales, sin asumir que todos los módulos comparten la misma regla.
- **Regresión:** request sin JS, selección/desselección y restauración, autorización real del consumidor.
- **Estado:** IMPLEMENTADO SIN VERIFICAR — inconsistencia demostrable por lectura; request pendiente.

### SYSTEM_ROLES-004 — P1 · PROPIO · Selección masiva incluye permisos ocultos por filtro

- **Evidencia:** `role_permissions_controller.js#filter` oculta filas según el texto buscado; `#selectGroup` cambia todos los toggles del grupo, sin excluir `row.hidden`.
- **Reproducción requerida:** buscar una acción de un módulo, usar «Seleccionar todo» en el módulo y comprobar que también se activan permisos no visibles; guardar y revisar permisos añadidos.
- **Riesgo:** sobreasignación accidental de privilegios.
- **Acción:** aclarar semántica visible (todo el módulo vs resultados filtrados); preferir seleccionar solo los resultados visibles o pedir confirmación explícita de la acción sobre todos. Mostrar conteos consistentes.
- **Regresión:** navegador con filtro parcial, grupos cerrados/abiertos y permisos previamente seleccionados.
- **Estado:** IMPLEMENTADO SIN VERIFICAR — confirmado por código; interacción pendiente.

### SYSTEM_ROLES-005 — P2 · PROPIO · Formularios incumplen validación por campo

- **Evidencia:** `app/views/system_roles/_form.html.erb` incluye `required: true` para nombre y resumen con `errors.full_messages`; no muestra `errors[:name]` bajo el campo, ni asteriscos rojos; tipo de rol usa `form.select` nativo.
- **Regla vigente:** validaciones en modelo/servidor; debajo de cada campo mostrar «nombreCampo mensajeValidación», marcado obligatorio en rojo, `aria-invalid` y `aria-describedby`; evitar resumen duplicado y `required` HTML5 como mecanismo de validación.
- **Acción:** unificar con componentes de formulario Delta POS; definir presentación para errores de permisos no asignables al único campo; mantener valores tras 422 y traducir es/en/ko.
- **Regresión:** crear/editar nombre vacío, largo o duplicado; tipo inválido; teclado/lector y 422.
- **Estado:** IMPLEMENTADO SIN VERIFICAR — confirmado por plantilla.

### SYSTEM_ROLES-006 — P2 · PROPIO · Revisión de estado sin feedback bajo motivo y confirmación

- **Evidencia:** `app/views/system_roles/status_review.html.erb` usa `required: true` para motivo y checkbox; muestra `@status_error` en alerta general y no asocia individualmente error/ayuda a cada campo.
- **Acción:** mantener validación en `StatusTransition`, devolver errores de motivo y confirmación junto a cada control; conservar texto y estado después de 422; sin resumen duplicado.
- **Regresión:** motivo vacío/excesivo, confirmación ausente, token caducado, teclado y foco.
- **Estado:** IMPLEMENTADO SIN VERIFICAR — confirmado por plantilla.

### SYSTEM_ROLES-007 — P2 · PROPIO · Normalización insuficiente del nombre

- **Evidencia:** `app/models/system_role.rb` valida longitud y unicidad `name` por `role_type`, sin `normalizes`, `case_sensitive: false` ni constraint de unicidad equivalente sin distinguir mayúsculas.
- **Riesgo:** variantes como `Vendedor` y `vendedor` o espacios laterales originan denominaciones difíciles de diferenciar y búsquedas confusas.
- **Acción:** normalización controlada; validación y índice PostgreSQL compatibles; definir migración/conversión para datos preexistentes antes de imponer unicidad.
- **Regresión:** variantes de caso/espacio, no romper roles actuales ni códigos estables.
- **Estado:** IMPLEMENTADO SIN VERIFICAR — confirmado por modelo; casos reales pendientes.

### SYSTEM_ROLES-008 — P2 · PROPIO/CONTRATO · Contador de usuarios con acceso residual puede ser optimista

- **Evidencia:** `StatusImpact#counts` calcula `without_other_roles` a partir de `UserRole.active` para otras asignaciones; `UserEffectiveRoles#effective_role_assignments` adicionalmente exige sucursal operativa para habilitar acceso.
- **Situación:** una asignación alternativa a una sucursal no operativa puede reducir el contador «sin otro rol activo» aunque no proporcione permisos efectivos.
- **Acción:** definir si el KPI representa «sin otro rol asignado activo» o «sin acceso efectivo»; alinear etiqueta, cálculo y prueba con sucursales no operativas y otras organizaciones.
- **Regresión:** rol alternativo en sucursal activa, cerrada/en preparación, distinto tenant y rol global.
- **Estado:** IMPLEMENTADO SIN VERIFICAR — confirmado por diferencia de definición; cálculo de casos pendiente.

## Matriz de seguimiento resumida

| ID | Prioridad | Propiedad | Prueba indispensable | Estado |
|---|---|---|---|---|
| SYSTEM_ROLES-001 | P1 | propio / contrato Usuarios | request multi-organización + definición de producto | implementado / sin verificar |
| SYSTEM_ROLES-002 | P1 | propio | auditoría de cambio de permisos en transacción | implementado / sin verificar |
| SYSTEM_ROLES-003 | P1 | propio / integración políticas | request sin JS + permiso efectivo | implementado / sin verificar |
| SYSTEM_ROLES-004 | P1 | propio | navegador con filtro y seleccionar todo | implementado / sin verificar |
| SYSTEM_ROLES-005 | P2 | propio | 422 por campo + accesibilidad | implementado / sin verificar |
| SYSTEM_ROLES-006 | P2 | propio | review 422 + validación de token | implementado / sin verificar |
| SYSTEM_ROLES-007 | P2 | propio | modelo y constraints | implementado / sin verificar |
| SYSTEM_ROLES-008 | P2 | propio / integración Sucursales | casos de sucursal no operativa | implementado / sin verificar |

## Implementación aplicada (2026-11-08)

Cada ID se conserva como se documentó en la auditoría. Las correcciones **están presentes en GitHub**, pero ninguna se ha cerrado sin evidencia del SHA final:

| ID | Corrección implementada | Archivos principales | Estado |
|---|---|---|---|
| SYSTEM_ROLES-001 | Reservar altas, ediciones y transiciones globales a `super_admin`; administradores consultan sin editar ni ver el historial global de actores | `SystemRolePolicy`, `SystemRolesController`, `views/system_roles/index/show` | IMPLEMENTADO / NO VERIFICADO |
| SYSTEM_ROLES-002 | Evento append-only por altas/bajas de permisos, guardado en transacción, vista con paginación y actor | `SystemRoles::PermissionUpdater`, `SystemRolePermissionAuditEvent`, migración `20261110010000`, `_permission_history` | IMPLEMENTADO / NO VERIFICADO |
| SYSTEM_ROLES-003 | Verificar `*.access` en el servidor y sincronizar accesos al marcar acciones en el editor sin alterar roles al abrirlos | `SystemRoles::PermissionSelection`, `role_permissions_controller.js` | IMPLEMENTADO / NO VERIFICADO |
| SYSTEM_ROLES-004 | La selección por grupo cambia solo permisos visibles; el texto del control lo identifica en es/en/ko | `role_permissions_controller.js`, `_permission_group`, locales | IMPLEMENTADO / NO VERIFICADO |
| SYSTEM_ROLES-005 | Mensajes junto a campo, asteriscos, `aria-invalid`/`aria-describedby`, formulario `novalidate` y dropdown Delta POS | `_form.html.erb`, `_permissions.html.erb`, `SystemRolesController` | IMPLEMENTADO / NO VERIFICADO |
| SYSTEM_ROLES-006 | Motivo y confirmación muestran errores bajo su control sin `required` HTML5 y conservan el texto del usuario tras 422 | `StatusTransition`, `SystemRoleStatusesController`, `status_review.html.erb` | IMPLEMENTADO / NO VERIFICADO |
| SYSTEM_ROLES-007 | Normalizar nombre, validar unicidad case-insensitive e índice funcional PostgreSQL | `SystemRole`, migración `20261110010100`, `db/schema.rb` | IMPLEMENTADO / NO VERIFICADO |
| SYSTEM_ROLES-008 | Calcular alternativas efectivas sobre sucursales operativas e incluir cambios de sucursal en el fingerprint de revisión | `SystemRoles::StatusImpact` | IMPLEMENTADO / NO VERIFICADO |

**Commits del módulo:** `ddf45c5` (seguridad, servicios y auditoría), `52d6581` (editor), `96167cc` (traducciones), `1f76ec4` (regresiones), `9128409` (schema), `7154d23` (protección de historial multiempresa), `9b01dc3` (YAML inglés), `5ae9fc8` (RuboCop/refactor), `dab7cd9` (paginación y sincronización explícita), `be216f7` (spec etiquetas); todos en `feature/fixes`.

**Pruebas nuevas:** `spec/requests/system_roles_security_spec.rb`, `spec/features/system_role_filtered_permissions_browser_spec.rb`, `spec/services/system_roles/status_impact_effective_roles_spec.rb`; también se actualizaron fixtures de superadministrador y specs existentes de roles.

**Operaciones de base de datos:** las dos migraciones están presentes y `db/schema.rb` está actualizado. **No afirmar que se aplicaron correctamente** hasta que termine el job Fresh migrations. La unicidad funcional puede requerir remediación de nombres legados duplicados (no se renombraron datos de usuario automáticamente).

## Cobertura existente localizada (no ejecutada en esta auditoría)

`spec/requests/system_roles_spec.rb`, `spec/requests/system_roles_editor_spec.rb`, `spec/requests/system_role_statuses_spec.rb`, `spec/features/system_roles_spec.rb`, `spec/features/system_roles_editor_browser_spec.rb`, `spec/features/system_role_statuses_browser_spec.rb`, `spec/models/system_role_spec.rb`, `spec/models/permission_spec.rb`, `spec/policies/system_role_policy_spec.rb`, `spec/services/system_roles/status_transition_spec.rb`, `spec/models/user_effective_roles_spec.rb` y specs de traducciones.

**Huecos principales:** pruebas de selección masiva filtrada, dependencias de permisos del lado servidor, auditoría de cambios de privilegios, autorización global entre organizaciones, errores debajo de cada campo, conteo de acceso efectivo en sucursales inactivas y verificación visual es/en/ko.

## Checklist de aceptación

- [x] Alcance inventariado; contratos externos delimitados.
- [x] Lectura de rutas, controladores, modelos, permisos, servicios, vistas, Stimulus y specs propios.
- [ ] Hallazgos P1 resueltos y casos negativos probados.
- [ ] Validaciones del modelo y mensajes individuales bajo cada campo.
- [ ] Estados vacío/carga/403/404/422/éxito y recuperación verificados por navegador.
- [ ] Desktop, móvil, lector de pantalla, teclado, foco, zoom 200 % y contraste verificados.
- [ ] Traducciones es/en/ko verificadas en ejecución.
- [ ] RSpec focalizado ejecutado y aprobado en SHA final.
- [ ] RuboCop, Brakeman, auditoría de dependencias e I18n ejecutados.
- [ ] GitHub Actions global verde en SHA de aceptación.
- [ ] Revisión independiente y aceptación final.

## Evidencias y verificaciones

| Fecha | SHA | Verificación | Resultado | Evidencia / limitación |
|---|---|---|---|---|
| 2026-11-08 | `8974fee011f9422066985a0ab088ed2d771e1c8a` | Revisión estática GitHub + heurísticas AI Dev Suite | REALIZADA | Inspección de archivos descritos; no ejecución de aplicación ni de CLIs externos |
| 2026-11-08 | `8974fee011f9422066985a0ab088ed2d771e1c8a` | CI general | EN CURSO al consultar | https://github.com/AliRodri1992/sales_point/actions/runs/42557591638 |
| 2026-11-08 | `8974fee011f9422066985a0ab088ed2d771e1c8a` | Hook configuration | PASÓ | https://github.com/AliRodri1992/sales_point/actions/runs/42557591788 ; no sustituye CI global |
| 2026-11-08 | `7154d23` | Rails I18n and YAML audit | PASÓ en ejecución previa `42559988289` (SHA `be216f7`; misma serie de cambios, no SHA final) | https://github.com/AliRodri1992/sales_point/actions/runs/42559988289 |
| 2026-11-08 | `be216f7` | Security scans | PASÓ en ejecución previa `42559988289` | https://github.com/AliRodri1992/sales_point/actions/runs/42559988289 |
| 2026-11-08 | `7154d23` y siguientes | RSpec / RuboCop / Fresh migrations | INICIADOS en GitHub Actions; ejecución cancelada por pushes concurrentes, sin resultado de aceptación | https://github.com/AliRodri1992/sales_point/actions/runs/42559988289 |
| 2026-11-08 | — | Comandos locales Ruby/Docker/RSpec focalizado | NO EJECUTADO | Sin acceso a la instancia Rails/Docker del usuario |
| 2026-11-08 | — | Pruebas manuales de navegador, capturas, dispositivos | NO EJECUTADO | No se dispone de instancia de la aplicación con sesión autorizada |

**Nota de concurrencia:** otros agentes realizan pushes de Plantillas, Usuarios y Sucursales sobre `feature/fixes`; se conservaron sus cambios y no se fusionó ninguna rama. GitHub Actions cancela ejecuciones anteriores al llegar nuevos pushes. Los fallos de lint y sintaxis en módulos ajenos (Inventario/Compras/Onboarding) observados en ejecuciones previas son EXTERNOS, no se atribuyen a Roles; pueden bloquear el CI global.

## Dependencias y traspasos

| Contrato | Propietario | Comprobación aquí | Fuera de alcance |
|---|---|---|---|
| Asignar/desasignar rol y revocar acceso desde próxima solicitud | Usuarios | bloqueos de nuevas asignaciones y aplicación de permisos | rediseño general de `/admin/users` |
| Sucursal operativa para permisos de rol de sucursal | Sucursales | cálculo e impacto de permisos efectivos | flujos de apertura/cierre de `/admin/branches` |
| Permisos de acción y permiso base `*.access` | consumidores/Políticas | contrato de permisos consistente con lo guardado | rediseño de módulos consumidores |

## Dictamen

**IMPLEMENTADO, PENDIENTE DE VERIFICACIÓN, NO CERRADO.** Los 8 hallazgos tienen cambios de código publicados, sin validación final de RSpec, Ruby lint, migraciones limpias y navegador. Se preservan IDs para toda regresión. El cierre exige correcciones, regresiones focalizadas, pruebas visuales, controles de calidad, CI global verde en SHA final y revisión independiente.

Política: [Estándar modular](../module-quality-standard.md) · [Plantilla ampliada](../module-audit-template.md).
