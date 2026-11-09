# Registro de calidad — Clientes (Delta POS)

**Estado:** Aislamiento por empresa IMPLEMENTADO EN CÓDIGO, **SIN VALIDACIÓN CI DEL ÚLTIMO SHA**. **NO CERRADO** por conciliación histórica, regresiones y aceptación visual.  
**Ruta propietaria:** `/admin/clients` (index, new, create, show, edit, update, destroy).  
**Rama:** `feature/fixes`. **SHA de implementación actual:** `9ca9f7059040482f3556b3c9b9e7a75a4f55e4ba`; pruebas focalizadas anteriores en `f4af7f7`, no equivalentes a validación del aislamiento.  
**Fecha:** 2026-11-09 · **Revisión independiente:** PENDIENTE · **Responsable de aceptación:** por asignar.

## Enfoque y alcance

Se aplicaron los procedimientos de **AI Dev Suite**: `ui-ux-pro-max` (estructura, tokens de marca, accesibilidad y estados), `impeccable-audit` (jerarquía, formularios, navegación y respuesta), y `ponytail-engineering` (cambios acotados, pruebas y regresiones). Las bibliotecas CLI originales no se instalaron; se utilizaron sus procedimientos junto con el conector GitHub y GitHub Actions.

**Archivos del módulo:** `app/controllers/admin/clients_controller.rb`, `app/models/client.rb`, `app/services/client_filter.rb`, `app/policies/client_policy.rb`, `app/views/admin/clients/*`, `config/locales/clients.{es,en,ko}.yml`, `spec/models/client_spec.rb`, `spec/requests/admin/clients_spec.rb`, `spec/features/clients_browser_spec.rb` y `.github/workflows/clients-ci.yml`.

**Límite:** Clientes y relaciones directas de contrato con teléfonos (`Phone`), notas (`Note`) y `SatFiscalRegime`. Ventas, facturación, fidelización y demás módulos **no** fueron rediseñados ni auditados internamente. Los problemas ajenos del CI general se reportan como externos.

## Hallazgos permanentes

| ID | Prioridad | Clase | Evidencia, causa raíz y adecuación | Estado |
|---|---|---|---|---|
| CLIENTS-001 | **P1** | PROPIO / Seguridad | Antes, `clients` no tenía `organization_id` y el controlador usaba un catálogo global. Se añadió columna/FK, índices únicos por empresa, asociación del modelo, `ClientPolicy::Scope`, rutas filtradas por `current_organization` y asignación segura en nuevas altas. La migración solo atribuye registros históricos cuando teléfonos/notas coinciden en una sola organización. | **IMPLEMENTADO; PENDIENTE validar CI y conciliar propietarios ambiguos** |
| CLIENTS-002 | P2 | PROPIO / UI | `index.html.erb`, `_list.html.erb`, `_panel.html.erb`, `_show.html.erb`: diseño anterior con acentos azules y jerarquía débil; reemplazado por tarjeta, tablas, estados y acciones de identidad esmeralda Delta POS. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-003 | P2 | PROPIO / UX | `ClientFilter` y listado tenían solo búsqueda y estado. Se incorporaron crédito, presencia de RFC y régimen fiscal, parámetros restringidos y escape de comodines SQL. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-004 | P2 | PROPIO / UX | Paginación mostraba todas las páginas sin ventana, incluso para grandes cantidades. Reutilización de `pagination_links(..., window: 2)` y tamaño configurable. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-005 | P2 | PROPIO / Formularios | `_form.html.erb`: campos sin secciones claras ni obligatoriedad visual. Ahora agrupados en General, Contacto, Fiscal y Comercial, con asteriscos de modelo, mensajes debajo de cada input y `novalidate` para que la validación de servidor sea la fuente de verdad. | IMPLEMENTADO / RSpec y Chrome PASARON |
| CLIENTS-006 | P2 | PROPIO / Persistencia | El campo `notes` se guarda en la tabla polimórfica. El nuevo `Client#organization` permite comprobar su organización en `Note` y `Phone` para escrituras nuevas. Los históricos contradictorios permanecen sin dueño para revisión. | IMPLEMENTADO EN CÓDIGO / pendiente revalidar después del cambio multiempresa |
| CLIENTS-007 | P2 | PROPIO / SAT | Permitir régimen SAT no vigente para nueva asociación fiscal era un riesgo. El modelo valida `SatFiscalRegime.current` al crear o cambiar de referencia; se conserva referencia histórica al editar otros campos. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-008 | P2 | PROPIO / Errores | Colisiones de índice único antes mostraban error global; ahora se asocian a código o RFC según índice, con feedback bajo campo. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-009 | P2 | PROPIO / Turbo | Baja lógica por Turbo no siempre actualizaba listado ni indicadores. Respuesta `destroy.turbo_stream.erb` actualiza tabla y métricas junto con notificación SweetAlert. | IMPLEMENTADO / pruebas HTTP focalizadas |
| CLIENTS-010 | P2 | PROPIO / Pruebas | Los requests de Clientes carecían de membresía de organización válida en el fixture (403 esperado incorrectamente como 200); corregidos contexto y pruebas de flujos. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-011 | P2 | PROPIO / I18n | Nueva UX requiere textos en español, inglés y coreano. Se añadieron y pasó revisión general I18n/YAML del commit correspondiente. | IMPLEMENTADO / revisión semántica manual pendiente |
| CLIENTS-012 | P3 | PROPIO / Accesibilidad | Hay cobertura en Chrome móvil y escritorio, pero **no** se ha completado evaluación manual de zoom 200 %, lector de pantalla, reducción de movimiento y contraste. | PENDIENTE |

## Aislamiento y conciliación de datos históricos

Se publicaron las siguientes medidas sin recrear ni eliminar la base de datos:

1. Migración `20261110130200_scope_clients_to_organizations.rb`: añade propiedad opcional de cliente con FK, recupera únicamente propietarios sustentados por evidencias coincidentes en `phones.organization_id` y `notes.organization_id`. Los registros ambiguos o sin evidencia **conservan su ID y permanecen sin asignar**.
2. Unicidad de código/RFC por organización con índices parciales, manteniendo unicidad independiente para registros históricos sin propietario.
3. `ClientsController` consulta únicamente `current_organization.clients.not_deleted`, construye las altas bajo la organización autenticada y devuelve 404 para IDs ajenos. La empresa no se acepta desde los parámetros del formulario.
4. `ClientPolicy::Scope`, `Organization#clients` y `Client#organization` habilitan comprobaciones coherentes de pertenencia para teléfonos y notas.
5. Especificaciones nuevas: `spec/requests/admin/clients_tenant_spec.rb` cubre listado, lectura, edición, baja, alta con `organization_id` falsificado, homónimos fiscales entre organizaciones, cuarentena de huérfanos y referencias de notas/teléfonos.
6. Se incorporó `bin/rails clients:ownership_audit` (solo lectura): presenta totales de clientes asignados, pendientes, con evidencia contradictoria y sin evidencia; **no** imprime datos personales ni modifica registros.

**Riesgo operativo deliberado:** tras migrar, los clientes que permanezcan sin `organization_id` dejarán de aparecer en el directorio hasta reconciliar su propiedad. Esto evita una exposición entre empresas, pero requiere auditoría de los datos reales y resolución supervisada. No debe asignárseles la primera empresa ni inferirse su pertenencia mediante RFC o nombre.

**Pendiente para cerrar CLIENTS-001:** comprobar la migración en una base histórica representativa, verificar los totales con `clients:ownership_audit`, resolver los registros ambiguos de forma trazable, ejecutar regresiones de dos organizaciones y lograr CI y aceptación independiente. No se ha certificado ninguna ejecución en la base de datos del usuario.

## Evidencias de verificación

- **PASÓ ANTES DEL AISLAMIENTO:** [Clients CI #42645858299](https://github.com/AliRodri1992/sales_point/actions/runs/42645858299) y [Clients CI #42646678169](https://github.com/AliRodri1992/sales_point/actions/runs/42646678169): cobertura de interfaz/CRUD, hasta **51 ejemplos, 0 fallos**, sobre SHA anteriores.
- **PENDIENTE, NO VALIDADO:** la batería de aislamiento sobre `de717b8`, `7fefa61` y `9ca9f70`. La primera ejecución detectó sintaxis incorrecta en specs y ajustes de RuboCop; ambos fueron corregidos en commits posteriores. [Clients CI #42671903209](https://github.com/AliRodri1992/sales_point/actions/runs/42671903209) finalizó con *failure* pero **sin jobs accesibles** en GitHub API; el intento de relanzar trabajos fallidos devolvió 403 (no reintentable). No es evidencia de tests verdes ni permite atribuir una causa definitiva.
- **CI global:** sigue sin estar verde en el SHA final. El resultado de RuboCop para el commit anterior `7fefa61` encontró solo un espacio en blanco adicional en `ClientsListing`, corregido en `9ca9f70`, pero aún sin resultado verificable de nueva ejecución.
- **Pendiente:** validar migración en base nueva e histórica, RuboCop, RSpec y Chrome del SHA de aislamiento; auditoría manual de zoom al 200 %, lector de pantalla, contraste y foco; conteo real de huérfanos, conciliación y aceptación independiente.

## Dictamen

**Rediseño visual validado previamente; aislamiento por organización incorporado al código, pero aún NO certificado por CI y sin conciliación de datos históricos. Expediente NO CERRADO.** No fusionar a `development` mientras falte la evidencia de cierre.

[Estándar modular](../module-quality-standard.md) · [Índice](README.md).
