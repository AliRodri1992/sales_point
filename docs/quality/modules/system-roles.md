# Registro de calidad — Roles y permisos

**Módulo y ruta principal:** Roles y permisos — `/system_roles`  
**Estado:** AUDITADO POR INSPECCIÓN ESTÁTICA · HALLAZGOS ABIERTOS · NO VERIFICADO · NO CERRADO.  
**Fecha de auditoría:** 2026-11-08 (America/Mexico_City).  
**Rama:** `feature/fixes`. **SHA de partida/auditado:** `8974fee011f9422066985a0ab088ed2d771e1c8a`.  
**SHA de aceptación:** PENDIENTE. **Responsable/revisor independiente:** PENDIENTE.  
**Método:** AI Dev Suite — Ponytail Engineering, Impeccable, UI UX Pro Max. Inspección real de código por GitHub; no se ejecutó el detector CLI de terceros.

> Este registro es la fuente de verdad de hallazgos del módulo. Lo observado en el código se distingue de las hipótesis y de pruebas pendientes. Un commit documental no equivale a una corrección ni al cierre de la auditoría. Conserva los IDs entre siguientes iteraciones.

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
- **Estado:** ABIERTO — decisión de seguridad y prueba de integración pendientes.

### SYSTEM_ROLES-002 — P1 · PROPIO · Sin auditoría durable de altas/bajas de permisos

- **Evidencia:** `SystemRolesController#replace_permissions` borra/crea asociaciones y solo emite `SystemRoleNotification` al actor. `SystemRoleStatusEvent` audita transiciones de estado, no el diff de permisos concedidos/revocados.
- **Riesgo:** no existe un historial propio, consultable e inmutable para reconstruir quién cambió qué permiso y cuándo; especialmente relevante para privilegios sensibles.
- **Acción:** evento de auditoría estructurado y append-only con actor, rol, permisos añadidos/revocados y contexto; escribir en la misma transacción que el cambio y presentar historial con autorización.
- **Regresión:** comparar evento antes/después, fallo transaccional, cambios concurrentes, protección de roles administrativos.
- **Estado:** ABIERTO — confirmado por código; no reproducido en ejecución.

### SYSTEM_ROLES-003 — P1 · PROPIO/CONTRATO · Dependencias `*.access` solo aplicadas por JavaScript

- **Evidencia:** `app/javascript/controllers/role_permissions_controller.js#refresh` activa `prefix.access` al seleccionar una acción de `languages/products/customers/users/categories`. `SystemRoles::PermissionSelection#valid?` valida únicamente IDs activos y no verifica esas dependencias. `CatalogPolicy#permitted_action?` exige ambos permisos.
- **Reproducción requerida:** enviar `PATCH /system_roles/:id/permissions` con `languages.update` pero sin `languages.access`; el controlador acepta la selección, mientras que la política no habilita la operación al usuario asignado.
- **Riesgo:** diferencias entre permisos guardados, opciones visibles y acceso efectivo. También puede surgir desmarcando manualmente `*.access` después de seleccionar una acción.
- **Acción:** decidir explícitamente entre autocompletar o rechazar con error contextual en servidor. Alinear el editor y las pruebas para todas las dependencias reales, sin asumir que todos los módulos comparten la misma regla.
- **Regresión:** request sin JS, selección/desselección y restauración, autorización real del consumidor.
- **Estado:** ABIERTO — inconsistencia demostrable por lectura; request pendiente.

### SYSTEM_ROLES-004 — P1 · PROPIO · Selección masiva incluye permisos ocultos por filtro

- **Evidencia:** `role_permissions_controller.js#filter` oculta filas según el texto buscado; `#selectGroup` cambia todos los toggles del grupo, sin excluir `row.hidden`.
- **Reproducción requerida:** buscar una acción de un módulo, usar «Seleccionar todo» en el módulo y comprobar que también se activan permisos no visibles; guardar y revisar permisos añadidos.
- **Riesgo:** sobreasignación accidental de privilegios.
- **Acción:** aclarar semántica visible (todo el módulo vs resultados filtrados); preferir seleccionar solo los resultados visibles o pedir confirmación explícita de la acción sobre todos. Mostrar conteos consistentes.
- **Regresión:** navegador con filtro parcial, grupos cerrados/abiertos y permisos previamente seleccionados.
- **Estado:** ABIERTO — confirmado por código; interacción pendiente.

### SYSTEM_ROLES-005 — P2 · PROPIO · Formularios incumplen validación por campo

- **Evidencia:** `app/views/system_roles/_form.html.erb` incluye `required: true` para nombre y resumen con `errors.full_messages`; no muestra `errors[:name]` bajo el campo, ni asteriscos rojos; tipo de rol usa `form.select` nativo.
- **Regla vigente:** validaciones en modelo/servidor; debajo de cada campo mostrar «nombreCampo mensajeValidación», marcado obligatorio en rojo, `aria-invalid` y `aria-describedby`; evitar resumen duplicado y `required` HTML5 como mecanismo de validación.
- **Acción:** unificar con componentes de formulario Delta POS; definir presentación para errores de permisos no asignables al único campo; mantener valores tras 422 y traducir es/en/ko.
- **Regresión:** crear/editar nombre vacío, largo o duplicado; tipo inválido; teclado/lector y 422.
- **Estado:** ABIERTO — confirmado por plantilla.

### SYSTEM_ROLES-006 — P2 · PROPIO · Revisión de estado sin feedback bajo motivo y confirmación

- **Evidencia:** `app/views/system_roles/status_review.html.erb` usa `required: true` para motivo y checkbox; muestra `@status_error` en alerta general y no asocia individualmente error/ayuda a cada campo.
- **Acción:** mantener validación en `StatusTransition`, devolver errores de motivo y confirmación junto a cada control; conservar texto y estado después de 422; sin resumen duplicado.
- **Regresión:** motivo vacío/excesivo, confirmación ausente, token caducado, teclado y foco.
- **Estado:** ABIERTO — confirmado por plantilla.

### SYSTEM_ROLES-007 — P2 · PROPIO · Normalización insuficiente del nombre

- **Evidencia:** `app/models/system_role.rb` valida longitud y unicidad `name` por `role_type`, sin `normalizes`, `case_sensitive: false` ni constraint de unicidad equivalente sin distinguir mayúsculas.
- **Riesgo:** variantes como `Vendedor` y `vendedor` o espacios laterales originan denominaciones difíciles de diferenciar y búsquedas confusas.
- **Acción:** normalización controlada; validación y índice PostgreSQL compatibles; definir migración/conversión para datos preexistentes antes de imponer unicidad.
- **Regresión:** variantes de caso/espacio, no romper roles actuales ni códigos estables.
- **Estado:** ABIERTO — confirmado por modelo; casos reales pendientes.

### SYSTEM_ROLES-008 — P2 · PROPIO/CONTRATO · Contador de usuarios con acceso residual puede ser optimista

- **Evidencia:** `StatusImpact#counts` calcula `without_other_roles` a partir de `UserRole.active` para otras asignaciones; `UserEffectiveRoles#effective_role_assignments` adicionalmente exige sucursal operativa para habilitar acceso.
- **Situación:** una asignación alternativa a una sucursal no operativa puede reducir el contador «sin otro rol activo» aunque no proporcione permisos efectivos.
- **Acción:** definir si el KPI representa «sin otro rol asignado activo» o «sin acceso efectivo»; alinear etiqueta, cálculo y prueba con sucursales no operativas y otras organizaciones.
- **Regresión:** rol alternativo en sucursal activa, cerrada/en preparación, distinto tenant y rol global.
- **Estado:** ABIERTO — confirmado por diferencia de definición; cálculo de casos pendiente.

## Matriz de seguimiento resumida

| ID | Prioridad | Propiedad | Prueba indispensable | Estado |
|---|---|---|---|---|
| SYSTEM_ROLES-001 | P1 | propio / contrato Usuarios | request multi-organización + definición de producto | abierto |
| SYSTEM_ROLES-002 | P1 | propio | auditoría de cambio de permisos en transacción | abierto |
| SYSTEM_ROLES-003 | P1 | propio / integración políticas | request sin JS + permiso efectivo | abierto |
| SYSTEM_ROLES-004 | P1 | propio | navegador con filtro y seleccionar todo | abierto |
| SYSTEM_ROLES-005 | P2 | propio | 422 por campo + accesibilidad | abierto |
| SYSTEM_ROLES-006 | P2 | propio | review 422 + validación de token | abierto |
| SYSTEM_ROLES-007 | P2 | propio | modelo y constraints | abierto |
| SYSTEM_ROLES-008 | P2 | propio / integración Sucursales | casos de sucursal no operativa | abierto |

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
| 2026-11-08 | — | RSpec focalizado / RuboCop / Brakeman / I18n | NO EJECUTADO | Acceso por API GitHub, sin proceso Rails/Docker de proyecto |
| 2026-11-08 | — | Pruebas manuales de navegador, capturas, dispositivos | NO EJECUTADO | No se dispone de instancia de la aplicación con sesión autorizada |

**Nota de concurrencia:** durante esta auditoría avanzó la rama a `956cb93dfbe6fe7bdd9d119f48e086ddf28ff2d0`, mediante un commit limitado a Plantillas de correo. No afecta los archivos propios de Roles y Permisos observados; el SHA inicial sigue siendo la base de esta inspección. Antes de corregir, comprobar HEAD y conservar cambios paralelos.

## Dependencias y traspasos

| Contrato | Propietario | Comprobación aquí | Fuera de alcance |
|---|---|---|---|
| Asignar/desasignar rol y revocar acceso desde próxima solicitud | Usuarios | bloqueos de nuevas asignaciones y aplicación de permisos | rediseño general de `/admin/users` |
| Sucursal operativa para permisos de rol de sucursal | Sucursales | cálculo e impacto de permisos efectivos | flujos de apertura/cierre de `/admin/branches` |
| Permisos de acción y permiso base `*.access` | consumidores/Políticas | contrato de permisos consistente con lo guardado | rediseño de módulos consumidores |

## Dictamen

**AUDITADO ESTÁTICAMENTE, NO VERIFICADO, NO CERRADO.** Cuatro hallazgos P1 y cuatro P2 quedan abiertos; no se han realizado correcciones de aplicación en esta auditoría. El cierre exige correcciones, regresiones focalizadas, pruebas visuales, controles de calidad, CI global verde en SHA final y revisión independiente.

Política: [Estándar modular](../module-quality-standard.md) · [Plantilla ampliada](../module-audit-template.md).
