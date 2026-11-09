# Registro único de calidad — Usuarios e invitaciones

> Registro actualizado conforme a [Estándar de calidad modular](../module-quality-standard.md) y [plantilla](../module-audit-template.md). **No confundir auditoría estática con prueba ejecutada ni CI especializado con cierre del módulo.**

- **Módulo:** Usuarios — directorio `/admin/users` y acciones propias de estados, invitaciones y restauración.
- **Rama:** `feature/fixes`.
- **SHA de partida de código:** `fe9f7aeb06f1c77026f6c81ba870d840b5095705` (2026-11-08).
- **SHA de último Users CI verde inspeccionado:** `a4a4f48826457972893fe03ce66a27eb88f043ec` (306 ejemplos, 0 fallos; RuboCop aprobado).
- **SHA de aceptación:** PENDIENTE. **Estado:** AUDITADO, NO CERRADO; hallazgos P1 y verificaciones pendientes.
- **Responsable de corrección:** módulo Usuarios; **revisión independiente:** pendiente de asignación.
- **Método:** AI Dev Suite — Impeccable (pantallas), UI UX Pro Max (UX/a11y) y Ponytail (lógica/seguridad), mediante inspección GitHub y logs de Actions. No se ejecutaron las CLIs originales.
- **Trazabilidad:** archivo preexistente de inventario actualizado. Los IDs siguientes se mantienen en rondas futuras; no generar copias o renumerarlos.

## 1. Frontera: rutas y pantallas propias

| Ruta / acción | Controlador, vista y componentes | Autorización y servicios | Cobertura existente |
|---|---|---|---|
| `GET /admin/users` | `Admin::UsersController#index`; `users/index`, `_list`, `_active_filters`, `_row_actions`, `_role_badges`; `users_filters_controller.js`; paginación global | `UserPolicy`, `UsersQuery`, `OrganizationMembership`, roles | `users_spec`, `users_listing_audit_spec`, `users_query_spec`, `admin_users_experience_spec` |
| `GET /admin/users/new` y `POST /admin/users` | `users/new`, `_form`; `user_access_controller.js` | `AdminAccountWriter`, `AdminAccountFormValidations`, `UserAdminAccessValidations`, `InvitationDispatcher`, capacidad | `users_spec`, `users_module_audit_spec`, `admin_account_writer_invitation_spec`, pruebas feature |
| `GET /admin/users/:id`, `GET /admin/users/:id/edit`, `PATCH /admin/users/:id` | `users/show`, `edit`, `_form`, roles y acciones | `UserPolicy`, `AdminAccountTenantGuard`, `BranchRoleAssignments` | `users_boundaries_spec`, `users_branch_roles_spec`, `users_module_audit_spec` |
| `GET/PATCH /admin/users/:id/status` | `Admin::UserStatusesController`, `user_statuses/edit` | `StatusTransition`, `StatusIncidentManager`, `StatusAdminSafety`, `UserStatusEvent` | `user_statuses_spec`, `status_transition_spec`, `status_transition_audit_spec` |
| `POST /admin/users/:id/invitation` | `Admin::UserInvitationsController`, acción del detalle | `InvitationEligibility`, `UserInvitation`, `InvitationDispatcher` | `user_invitations_spec`, `user_invitation_spec`, `invitation_delivery_job_spec` |
| `GET /admin/user_restorations`, `POST /admin/users/:id/restoration` | `Admin::UserRestorationsController`, `user_restorations/index` | `AccountRestoration`, capacidad, invitación condicionada | `user_restorations_spec`, `account_restoration_spec` |
| `GET/PATCH /invitations/accept` | `UserInvitationsController`, `user_invitations/show`, `invalid` | `UserInvitation#accept!/#accept_existing!`; token de un uso | `requests/user_invitations_spec`, `user_invitation_concurrency_spec` |
| Cambio de empresa desde selector superior (frontera de Usuarios) | `Admin::OrganizationSelectionsController`, selector compartido | Membresía accesible y contexto `CurrentOrganizationAccess` | `organization_selections_spec`, `users_cross_organization_permissions_spec` |

**Excluidos:** auditoría completa de Registro/Sign in, Onboarding, Sucursales, Inventario, Terminales, Proveedores y motor/editor de Plantillas de correo. Se verifican únicamente sus contratos cuando afectan directamente a las acciones de Usuarios.

## 2. Resultados positivos verificados por código o CI

- Las rutas administrativas utilizan Pundit y la lista limita usuarios a membresías de la organización seleccionada. Hay regresiones para acceso cruzado y selección de empresa.
- La creación administrativa persiste la cuenta pendiente y exige roles para empleados; las validaciones principales residen en modelo/servicio y la vista presenta mensajes por campo y asteriscos rojos sin usar `required` HTML5.
- El flujo de invitación usa token aleatorio, hash SHA-256 almacenado, vencimiento de 72 horas, aceptación de un solo uso, revalidación bajo bloqueo y confirmación de titular para una segunda empresa.
- Restauración y cambios de estado tienen bloqueo transaccional, políticas, razones, eventos e incidentes; el flujo de restauración simple impide enviar invitación a empleado sin rol.
- El listado presenta tabla de escritorio, tarjetas en móvil, filtros, paginación y estados vacíos; hay pruebas automatizadas de navegador a anchura de 390 px, **sin que eso equivalga a auditoría visual manual**.
- Comparación estática de ocho familias de traducciones de Usuarios entre `es/en/ko`: igual número de claves y mismos interpoladores en las familias inspeccionadas. La auditoría YAML general pasó en el SHA inspeccionado.

## 3. Registro único de hallazgos

**Leyenda:** `confirmado por código` describe una condición verificable en la implementación; **no** equivale a falla reproducida por navegador. `Hipótesis` significa que faltan prueba o decisión de producto. Ningún hallazgo de esta tabla está cerrado.

| ID | Prioridad / clase | Evidencia y condición de reproducción | Causa raíz y adecuación propuesta | Regresión requerida | Estado / responsable |
|---|---|---|---|---|---|
| **USERS-001** | **P1 PROPIO** | **Confirmado por código:** los cambios de roles globales y por sucursal se escriben en `app/services/users/admin_account_writer.rb` y `branch_role_assignments.rb` sobre `UserRole`, que no tiene `has_paper_trail` ni evento estructurado con actor. `UserStatusEvent` cubre estados, no cambios de roles. | Incorporar auditoría durable y consultable de concesión/revocación de roles y cambios sensibles, reutilizando PaperTrail o el mecanismo existente; asociar actor, organización, antes/después y fecha. No duplicar notificaciones con auditoría. | Crear/revocar rol general y de sucursal, comprobar historia de ambos y aislamiento de empresa; cubrir concurrencia y rollback. | **VERIFICADO EN USERS CI `cc009709`** · regresión automatizada aprobada; cierre global pendiente |
| **USERS-002** | **P1 PROPIO — contrato por decidir** | **Comportamiento confirmado; defecto sujeto a regla de negocio:** `User#admin?` y `UserEffectiveRoles#effective_role_assignments` admiten roles globales (`branch_id: nil`) en cualquier organización accesible. La prueba de aislamiento existente cubre rol de sucursal extranjero, no un rol global administrativo de cuenta compartida. | Acordar explícitamente si un rol administrativo global debe tener efectos en **todas** las empresas a las que se une el mismo usuario. Si no, introducir concesiones por empresa y no asumir equivalencia entre membresía y autoridad. | Usuario con dos membresías, administrador en empresa A y sin concesión B; verificar permisos reales en ambas y negar escalado según decisión formal. | **ABIERTO / HIPÓTESIS DE SEGURIDAD** · Usuarios/arquitectura |
| **USERS-003** | **P1 PROPIO** | **Confirmado por código:** en `AccountRestoration#restore_account!`, una cuenta compartida globalmente activa pasa de membresía eliminada a **activa**; `reset_local_access!` revoca sus roles de sucursal sin comprobar que el empleado conserve otros roles válidos. El alta por invitación sí exige roles. | Resolver la asimetría de reglas de reactivación: para empleados, exigir roles operativos válidos o restaurar como pendiente de asignación antes de habilitar la membresía local, preservando acceso legítimo a otras empresas. | Caso compartido con único rol local: restaurar, comprobar estado de acceso y posibilidad de invitar/activar tras asignar rol; conservar otra membresía. | **VERIFICADO EN USERS CI `cc009709`** · regresión automatizada aprobada; cierre global pendiente |
| **USERS-004** | **P2 PROPIO** | **Confirmado por código, condición de permisos revocados:** `UserPolicy#resend_invitation?` hereda la exención de administrador de `CatalogPolicy`, por lo que el botón puede mostrarse; `Admin::UserInvitationsController#validate_access!` exige además permiso explícito `users.resend_invitation` y responde 403. | Centralizar la misma comprobación de permiso para política, vista y controlador; mostrar estado no disponible con explicación cuando corresponda. | Administrador con el permiso removido: botón ausente y POST 403; administrador con permiso: botón y POST válidos. | **VERIFICADO EN USERS CI `cc009709`** · regresión automatizada aprobada; cierre global pendiente |
| **USERS-005** | **P2 PROPIO** | **Riesgo confirmado por ruta ORM, rendimiento no medido:** `_role_badges.html.erb` y `users/show.html.erb` llaman `branch.operationally_active?`, que consulta `branch.organization` en `BranchLifecycle`; `UsersController` precarga `:branch` pero no `branch: :organization`. | Precargar organización de cada sucursal en listado y detalle o calcular el estado sin consultas adicionales; revisar cantidad de SQL para 10/50 filas. | Spec con contador de consultas para N usuarios, roles y sucursales, asegurando crecimiento acotado y ausencia de N+1. | **VERIFICADO EN USERS CI `cc009709`** · regresión automatizada aprobada; cierre global pendiente |
| **USERS-006** | **P2 PROPIO** | **Confirmado por código:** campos `reason`/`resolution` de `user_statuses/edit` y `reason` de `user_restorations/index` muestran asterisco rojo, pero no expresan `aria-required`/texto accesible como sí ocurre en el alta de Usuarios; validación de servidor sí existe. | Añadir obligatoriedad semántica sin activar HTML5 `required`; mantener error individual con `aria-describedby` y foco tras 422. | Solicitudes inválidas con Nokogiri; navegación con teclado y lector de pantalla en formulario de estado y restauración. | **VERIFICADO EN USERS CI `cc009709`** · regresión automatizada aprobada; cierre global pendiente |
| **USERS-007** | **P2 PROPIO** | **Confirmado por código:** tabla de `users/_list.html.erb` presenta columnas ordenables mediante `sort_link`, pero el `th` no expone `aria-sort` ni la dirección activa en su nombre accesible. | Añadir estado/dirección de orden a encabezado e interacción accesible sin romper URLs y filtros. | Orden asc/desc con inspección HTML `aria-sort`, navegación por teclado y lector de pantalla. | **VERIFICADO EN USERS CI `cc009709`** · regresión automatizada aprobada; cierre global pendiente |
| **USERS-008** | **P2 PROPIO — caso histórico** | **Hipótesis reproducible con fixture:** los KPI de `UsersController#index` cuentan membresías por `account_status`, mientras el listado cruza `policy_scope(User).not_deleted`. Con miembro local activo pero usuario globalmente archivado, podría contarse sin aparecer en resultados. | Alinear el universo de los contadores con `scoped_users` o etiquetar los KPI como membresías, indicando estados inconsistentes. | Fixture cuenta globalmente archivada + membresía local activa: contador igual al alcance visible; 0 ocultamientos. | **VERIFICADO EN USERS CI `cc009709`** · regresión automatizada aprobada; cierre global pendiente |
| **USERS-009** | **P2 PROPIO — datos históricos** | **Hipótesis:** `StatusTransition.allowed_targets` para `blocked` depende de un `UserStatusEvent` previo. Si el estado bloqueado procede de datos heredados sin evento, solo ofrece eliminación; `StatusIncidentManager` también exige incidente abierto para desbloquear. | Diseñar recuperación administrativa auditada de bloqueos históricos sin evento/incidente, sin suprimir la obligación de justificar desbloqueo. | Fixture bloqueado sin evento o sin incidente: respuesta controlada, recuperación autorizada o mensaje de soporte, nunca fallo inesperado. | **VERIFICADO EN USERS CI `cc009709`** · regresión automatizada aprobada; cierre global pendiente |
| **USERS-010** | **P2 PROPIO — UI por verificar** | **No comprobado en navegador:** tras 422 en alta/edición, hay mensajes por campo pero falta evidencia real de foco en primer error, contraste, teclado, zoom 200 %, contenido largo y lector de pantalla. El controlador Stimulus actual actualiza el resumen, no enfoca errores explícitamente. | Ejecutar auditoría manual y adaptar foco/anuncios accesibles solo ante reproducción; conservar validaciones de modelo sin resumen duplicado. | Capturas y recorrido real desktop/móvil, zoom 200 %, tabulación, lector y 422; asociar evidencia al SHA final. | **PENDIENTE DE VERIFICACIÓN** · Usuarios/UX |
| **USERS-011** | **P3 PROPIO — diseño por evaluar** | **Hipótesis de densidad:** `users/index.html.erb` ocupa cinco tarjetas KPI antes de filtros y tabla. El estándar de Delta POS no exige KPI por módulo; la necesidad de esos cinco indicadores no está justificada con evidencia de usuarios. | Evaluar simplificar a resumen compacto si reduce desplazamiento y mejora flujo de administración sin perder estados útiles. | Prueba visual móvil/escritorio, tarea de búsqueda/edición y comparación de altura/scroll. | **PENDIENTE DE VALIDACIÓN UX** · Usuarios/diseño |
| **USERS-012** | **P0 de proceso — EXTERNO** | **CI general no verde:** en [CI del SHA `fe9f7aeb`](https://github.com/AliRodri1992/sales_point/actions/runs/42550692900) RuboCop indicó **50 ofensas** principalmente en Sucursales, Inventarios, Onboarding y Compras; también halló error de sintaxis en una spec FEFO externa. Seguridad e I18n pasaron; RSpec general fue cancelado. | Transferir a los expedientes de esos módulos, sin modificar su lógica desde esta auditoría de Usuarios. Aun siendo externo, impide cerrar el módulo en un SHA de aceptación no verde. | CI global completo y verde en el SHA de aceptación. | **ABIERTO / BLOQUEO EXTERNO** · dueños de módulos vecinos |

| **USERS-013** | **P2 PROPIO — petición UX** | **Implementado en código y probado en CI anterior:** la baja se inicia desde un `<dialog>` en el listado y detalle, sin visitar otra pantalla. La confirmación exige `reason` validado por Rails, devuelve error 422 inline y respeta Pundit. | Conservar modal accesible, cierre por cancelar/Escape, foco restaurado, manejo de error y registro de baja. El formulario de estado directo queda como alternativa técnica para otros cambios de estado. | `spec/features/admin_users_experience_spec.rb` (baja con 422 y éxito; nuevo escenario Escape desde detalle), `spec/requests/admin/user_statuses_spec.rb`. | **VERIFICADO EN USERS CI `a4a4f488`** · 306 pruebas verdes, Escape y foco comprobados en Chrome automatizado; validación manual pendiente |

### Reauditoría UI/UX de modal — 2026-11-08

- **USERS-013 (mismo ID, sin duplicar hallazgo):** en `app/views/admin/users/_deactivation_modal.html.erb`, el `dialog` no declaraba posición fija ni centrado explícito; el comportamiento visual dependía de estilos nativos y globales. **Corregido en código** en `e59aafce`: `fixed inset-0 m-auto`, límite de altura por viewport dinámico y desplazamiento interno en pantallas pequeñas/zoom.
- Se conservan `showModal()`, foco inicial al motivo, Escape/cancelación con restauración de foco, validación en Rails y mensajes de error por campo; **inspeccionado estáticamente**, no probado de nuevo en navegador real.
- Validación pendiente para este nuevo SHA: Users CI y CI global, zoom 200 %, viewport móvil y lector de pantalla. La verificación anterior de 306 pruebas pertenece únicamente a `a4a4f488`.
- En la auditoría de este pase también se revisaron `UsersController`, `UserStatusesController`, `UserPolicy`, modelo `User`, directorio, detalle y controlador Stimulus. **USERS-002 continúa abierto**; no modificar privilegios multiempresa sin contrato definido.

### Adecuaciones complementarias — 2026-11-08

- **USERS-010:** el controlador `user_access_controller.js` ahora muestra cualquier acordeón que contenga el primer control `aria-invalid="true"`, enfoca el control y deja que el navegador lo desplace al área visible. Cambio publicado en `d77db915`; falta CI del SHA definitivo. Se agregó además una aserción de foco sobre un checkbox inválido de roles en `5c33d451`.
- **USERS-013:** incorporada regresión Capybara para centrado horizontal/vertical, permanencia dentro del viewport de 390 × 420 y cierre sin cambiar el estado de cuenta. Prueba publicada en `9d245f2e`; su resultado **no está certificado** hasta completar Users CI.
- **USERS-002:** sigue como decisión contractual de seguridad sobre roles globales en distintas organizaciones. No se cambia la concesión de privilegios sin regla formal y migración de datos.
- **USERS-011:** se conservan los KPI existentes; no se dispone de pruebas de usabilidad que justifiquen eliminarlos.
- Las pruebas automatizadas de geometría no sustituyen una revisión manual con zoom real 200 %, lector de pantalla ni comprobación visual de contraste. El SHA de aceptación permanece pendiente.

### Ronda de adecuaciones — foco de errores y decisión multiempresa (2026-11-08)

- **USERS-010:** corrección adicional implementada en el formulario y Stimulus: un error de `branch_role_assignments` permite enfocar el grupo con nombre y descripción de error, incluso sin control individual `aria-invalid`. Se agregó una prueba de navegador para selección inválida y foco. **Estado: implementado en código; Users CI del nuevo SHA pendiente de comprobar.**
- **USERS-013:** el centrado del diálogo y la prueba de viewport reducido permanecen implementados. La última ejecución especializada de `5c33d451` **aprobó** RSpec de Usuarios y RuboCop específico; no equivale a revisión manual de zoom ni lector de pantalla.
- **USERS-002:** confirmado por `UserRole`, `UserEffectiveRoles` y `AdminAccountWriter`: los roles de tipo `system` son asignaciones globales sin `organization_id`. **Decisión de arquitectura pendiente:** el aislamiento estricto requiere una asignación por organización, migración de datos y cambio consistente de autorización en todos los servicios consumidores; no introducir un filtro aislado que deje administradores legítimos sin acceso ni asegurar falsamente que está corregido.
- **USERS-011:** se mantienen los cinco KPI existentes hasta obtener evidencia de una mejora medible.
- **CI general de referencia** en `79a3d008`: migraciones, seguridad e I18n aprobaron; RuboCop global detectó **33 infracciones** en archivos externos a Usuarios, incluidas dos specs con errores de sintaxis; RSpec global seguía en curso al consultarse. El CI global del SHA final debe aprobar antes del cierre.

### Adecuaciones verificables de esta ronda — 2026-11-08

- **USERS-002 · mitigación de acceso entre empresas:** `UserEffectiveRoles#effective_role_assignments` exige una membresía `accessible` en la organización cuando el llamador especifica `organization:`; antes una asignación de sistema podía evaluarse para una organización sin membresía accesible. Se añadieron pruebas para organización ajena y membresía suspendida. Commits: `cb4dae48`, `c02aa50f`. **No se considera cerrado USERS-002:** los roles de sistema todavía se comparten entre organizaciones en las que el usuario sí tiene membresía accesible. Se requiere contrato de producto y migración de concesiones por organización para cambiar esa semántica.
- **CI especializado, bloqueo puntual:** en el run `42559189815` RuboCop aprobó, pero las pruebas de Usuarios no llegaron a ejecutarse porque `20261110010000_create_system_role_permission_audit_events.rb` carecía de `end` al cerrar la clase. Corregido en `c9949257`. Los últimos runs requieren comprobación posterior.
- **Validación visual real:** no ejecutada en el navegador de macOS con zoom 200 % ni lector de pantalla; no atribuir cierre visual a tests Capybara.
- **CI global:** no considerar aprobado mientras haya infracciones externas o ejecuciones canceladas.

## 4. Matriz de aceptación por pantalla

| Pantalla / flujo | Servidor, autorización y datos | UX y errores | Evidencia aún exigida |
|---|---|---|---|
| Listado / filtros | Aislamiento, filtro por estado local, búsqueda, rol/sucursal y paginación tienen specs | Vacío y tarjetas móviles codificados; ordenar con `aria-sort` pendiente | Desktop, móvil, filtros cruzados, foco/teclado, 401/403, 0/50 registros y N+1 |
| Nuevo usuario | Validaciones modelo, rol mínimo empleado, cuenta pendiente, invitación y límite de empresa | Mensajes por campo, `novalidate`, asteriscos y selector Delta | 422 completo, caracteres largos, JS deshabilitado, empleado sin rol, fallo de cola y duplicado concurrente |
| Editar usuario | Tenant guard, roles de sistema/sucursal, protección último admin, revocación de sesión | Resumen en vivo y controles de roles | Multiempresa con administrador y cambios concurrentes de roles; foco tras 422 |
| Detalle | Estados locales, invitación, historial de estatus/incidentes y permisos | Acciones iconográficas con etiquetas accesibles | Acciones con permisos revocados, estados vencidos, permisos sólo lectura |
| Estado y bloqueo | `StatusTransition`, razones, incidentes y reversión protegida | Error individual y advertencia de sesiones compartidas | Bloqueo legado sin incidente, semántica de requerido, confirmación, éxito y 422 |
| Restauración | Se exige razón y se revocan permisos históricos | Formulario con error por campo | Empleado compartido, recuperación con rol nuevo, teclado/foco y paginación |
| Aceptación invitación | Token de un uso, expiración, titular de cuenta compartida, validaciones | Mensajes de enlace inválido y contraseña | Usos duplicados concurrentes, navegación de regreso e interacción real con proveedor de correo |

## 5. Historial de verificación (no equiparar código con ejecución)

| Fecha | SHA | Verificación / fuente | Resultado comprobado | Limitaciones |
|---|---|---|---|---|
| 2026-11-08 | `cc009709` | [Users CI](https://github.com/AliRodri1992/sales_point/actions/runs/42556099051) tras corregir hallazgos y modal | **PASÓ: 305 ejemplos, 0 fallos; RuboCop específico PASÓ** | Inspección visual manual y CI general pendientes |
| 2026-11-08 | `513700ea` | [Users CI](https://github.com/AliRodri1992/sales_point/actions/runs/42557051637), incluida política `UserPolicy` en lint especializado | **PASÓ: 305 ejemplos, 0 fallos; RuboCop específico PASÓ** | Última prueba de teclado de modal publicada después en `a4a4f488` |
| 2026-11-08 | `a4a4f488` | [Users CI](https://github.com/AliRodri1992/sales_point/actions/runs/42557254742): prueba Escape/cancelación de modal y restauración de foco | **PASÓ: 306 ejemplos, 0 fallos; RuboCop específico PASÓ** | No atribuir verificación por un commit |
| 2026-11-08 | `97a8c488` | [Users CI](https://github.com/AliRodri1992/sales_point/actions/runs/42549788993): RuboCop y RSpec con browser feature specs | **PASÓ: 293 ejemplos, 0 fallos; RuboCop específico PASÓ** | SHA previo al estándar documental; no equivale a prueba manual integral ni CI global |
| 2026-11-08 | `fe9f7aeb` | [CI general](https://github.com/AliRodri1992/sales_point/actions/runs/42550692900) | **FALLÓ** RuboCop: 50 ofensas; **PASÓ** seguridad e I18n; RSpec completo y migraciones cancelados | Problemas propios de módulos vecinos; cierre global bloqueado |
| 2026-11-08 | `fe9f7aeb` | Inspección GitHub de rutas, controladores, modelos, servicios, vistas, JS, esquema y tests propios | **REVISADO POR CÓDIGO**; hallazgos USERS-001–011 | No es test ejecutado ni demuestra incidencia visible |
| 2026-11-08 | `fe9f7aeb` | Comparación estática de claves e interpolaciones de ocho familias `users*` / `user_*` de `es/en/ko` | **PASÓ inspección de paridad** en familias revisadas | No certifica cada texto renderizado dinámicamente |
| 2026-11-08 | — | Navegador real local, lector de pantalla, zoom 200 % y pruebas manuales de extremo a extremo | **NO EJECUTADO** | La lectura de `localhost` no estaba disponible en esta sesión |
| 2026-11-08 | — | Docker/Overcommit local, CI global verde sobre SHA de aceptación y revisión independiente | **NO EJECUTADO / NO CONFIRMADO** | Pendientes |

**CI general de referencia tras las adecuaciones:** [run 42557434502](https://github.com/AliRodri1992/sales_point/actions/runs/42557434502) en `af782051`: seguridad e I18n **PASARON**; RuboCop global **FALLÓ con 54 ofensas**, ninguna en archivos propios de Usuarios. RSpec general y migraciones todavía estaban en ejecución al consultar. No confundir este bloqueo externo con una prueba específica fallida de Usuarios.

## 6. Contratos de integración y traspasos

| Contrato de Usuarios | Qué se valida desde Usuarios | Propietario externo | Fuera de alcance |
|---|---|---|---|
| Selección de empresa / sucursal | La organización actual es accesible y ningún rol de sucursal extranjera autoriza acciones propias | Organización / Sucursales | Auditoría integral del CRUD de Sucursales |
| Plantilla y cola de invitaciones | Encolar, informar fallos, token cifrado en el job y enlace de activación con vigencia | Plantillas de correo / Entrega | Motor completo de rendering, SMTP/DNS, branding y Gmail/Outlook |
| Login y sesiones | Reactivación, revocación y vinculación de cuenta compartida devuelven acceso conforme a membresía | Autenticación | Rediseño completo de login/signup/recuperación |
| Plan de membresía / capacidad | Prohibir alta/recuperación cuando no hay asientos, mostrar error claro | Membresías | Cálculo completo de facturación del plan |
| CI general | Debe estar verde para SHA de aceptación | Dueños de módulos con ofensas | Reparar FEFO, Inventarios, Sucursales u Onboarding en este expediente |

## 7. Checklist de cierre

- [x] Alcance delimitado desde rutas propias y contratos externos identificados.
- [x] Inventario de archivos, acciones, vistas, pruebas y flujos propios inspeccionado.
- [x] Reglas principales de formularios, Pundit, modelos, membresías y soft delete revisadas estáticamente.
- [x] RSpec especializado (306 ejemplos), prueba de modal con teclado y RuboCop verde en SHA `a4a4f488`.
- [x] Comparación estática de claves e interpoladores de ocho familias es/en/ko; auditoría I18n general verde en SHA inspeccionado.
- [ ] USERS-001 y USERS-003 con regresiones verdes; **USERS-002 sigue abierto** hasta fijar el contrato de roles globales por empresa.
- [ ] P2 corregidos o aceptados por propietario con motivo y pruebas.
- [ ] Estados de red/401/403/404/422 y éxito/reintentos navegados en todas las pantallas.
- [ ] Accesibilidad real: móvil/escritorio, foco, teclado, 200 %, contraste, lector y reduced motion.
- [x] Auditoría durable de cambios de roles y medición N+1 cubiertas con specs y Users CI verde en `cc009709`.
- [ ] CI global **completo y verde** en el SHA de aceptación, con jobs de RSpec, RuboCop, seguridad, YAML e inicialización de BD.
- [ ] Revisión independiente del mismo expediente y mismo SHA después de los arreglos.

## 8. Dictamen y regla de reapertura

**IMPLEMENTADO PARCIALMENTE Y VERIFICADO EN CI ESPECIALIZADO, NO CERRADO.** USERS-001 y USERS-003 cuentan con regresiones verdes; USERS-002 permanece pendiente de decisión arquitectónica multiempresa. Ninguno debe etiquetarse “reproducido en navegador” sin ejecución; `USERS-002` exige confirmar la regla de negocio. El CI especializado de `a4a4f488` tiene 306 pruebas verdes, pero CI general del SHA inspeccionado falla por módulos externos y no existe evidencia visual manual.

**Próximo paso técnico:** corregir o decidir P1; crear pruebas de regresión; después P2, mediciones, UI real, CI especializado y general del SHA final y reauditoría independiente sobre estos **mismos IDs**. No fusionar con CI requerido fallido o pendiente.

Referencia: [calidad modular](../module-quality-standard.md) · [plantilla](../module-audit-template.md).
