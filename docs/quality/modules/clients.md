# Registro de calidad — Clientes (Delta POS)

**Estado:** AUDITADO Y REDISEÑADO, **NO CERRADO** por CLIENTS-001 y verificación visual independiente.  
**Ruta propietaria:** `/admin/clients` (index, new, create, show, edit, update, destroy).  
**Rama:** `feature/fixes`. **SHA de ejecución focalizada aprobada:** `f4af7f7f8339bacf79c42b3cefa596136ef6b4d9`.  
**Fecha:** 2026-11-09 · **Revisión independiente:** PENDIENTE · **Responsable de aceptación:** por asignar.

## Enfoque y alcance

Se aplicaron los procedimientos de **AI Dev Suite**: `ui-ux-pro-max` (estructura, tokens de marca, accesibilidad y estados), `impeccable-audit` (jerarquía, formularios, navegación y respuesta), y `ponytail-engineering` (cambios acotados, pruebas y regresiones). Las bibliotecas CLI originales no se instalaron; se utilizaron sus procedimientos junto con el conector GitHub y GitHub Actions.

**Archivos del módulo:** `app/controllers/admin/clients_controller.rb`, `app/models/client.rb`, `app/services/client_filter.rb`, `app/policies/client_policy.rb`, `app/views/admin/clients/*`, `config/locales/clients.{es,en,ko}.yml`, `spec/models/client_spec.rb`, `spec/requests/admin/clients_spec.rb`, `spec/features/clients_browser_spec.rb` y `.github/workflows/clients-ci.yml`.

**Límite:** Clientes y relaciones directas de contrato con teléfonos (`Phone`), notas (`Note`) y `SatFiscalRegime`. Ventas, facturación, fidelización y demás módulos **no** fueron rediseñados ni auditados internamente. Los problemas ajenos del CI general se reportan como externos.

## Hallazgos permanentes

| ID | Prioridad | Clase | Evidencia, causa raíz y adecuación | Estado |
|---|---|---|---|---|
| CLIENTS-001 | **P1** | PROPIO / Seguridad | `db/schema.rb`, tabla `clients`, y `Client.not_deleted` en controller: **no existe `organization_id`** ni FK al tenant. Listado, consulta, edición y baja pueden acceder a registros globales si el usuario tiene permiso de Clientes. Unicidad de código/RFC también es global. **No se cambió la propiedad histórica sin evidencia fiable.** | **ABIERTO, BLOQUEANTE** |
| CLIENTS-002 | P2 | PROPIO / UI | `index.html.erb`, `_list.html.erb`, `_panel.html.erb`, `_show.html.erb`: diseño anterior con acentos azules y jerarquía débil; reemplazado por tarjeta, tablas, estados y acciones de identidad esmeralda Delta POS. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-003 | P2 | PROPIO / UX | `ClientFilter` y listado tenían solo búsqueda y estado. Se incorporaron crédito, presencia de RFC y régimen fiscal, parámetros restringidos y escape de comodines SQL. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-004 | P2 | PROPIO / UX | Paginación mostraba todas las páginas sin ventana, incluso para grandes cantidades. Reutilización de `pagination_links(..., window: 2)` y tamaño configurable. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-005 | P2 | PROPIO / Formularios | `_form.html.erb`: campos sin secciones claras ni obligatoriedad visual. Ahora agrupados en General, Contacto, Fiscal y Comercial, con asteriscos de modelo, mensajes debajo de cada input y `novalidate` para que la validación de servidor sea la fuente de verdad. | IMPLEMENTADO / RSpec y Chrome PASARON |
| CLIENTS-006 | P2 | PROPIO / Persistencia | El campo `notes` está respaldado por la asociación polimórfica y no es una columna ordinaria. El formulario usa el atributo virtual `notes`; se prueba persistencia y lectura en expediente. | IMPLEMENTADO / RSpec y Chrome PASARON |
| CLIENTS-007 | P2 | PROPIO / SAT | Permitir régimen SAT no vigente para nueva asociación fiscal era un riesgo. El modelo valida `SatFiscalRegime.current` al crear o cambiar de referencia; se conserva referencia histórica al editar otros campos. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-008 | P2 | PROPIO / Errores | Colisiones de índice único antes mostraban error global; ahora se asocian a código o RFC según índice, con feedback bajo campo. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-009 | P2 | PROPIO / Turbo | Baja lógica por Turbo no siempre actualizaba listado ni indicadores. Respuesta `destroy.turbo_stream.erb` actualiza tabla y métricas junto con notificación SweetAlert. | IMPLEMENTADO / pruebas HTTP focalizadas |
| CLIENTS-010 | P2 | PROPIO / Pruebas | Los requests de Clientes carecían de membresía de organización válida en el fixture (403 esperado incorrectamente como 200); corregidos contexto y pruebas de flujos. | IMPLEMENTADO / RSpec focalizado PASÓ |
| CLIENTS-011 | P2 | PROPIO / I18n | Nueva UX requiere textos en español, inglés y coreano. Se añadieron y pasó revisión general I18n/YAML del commit correspondiente. | IMPLEMENTADO / revisión semántica manual pendiente |
| CLIENTS-012 | P3 | PROPIO / Accesibilidad | Hay cobertura en Chrome móvil y escritorio, pero **no** se ha completado evaluación manual de zoom 200 %, lector de pantalla, reducción de movimiento y contraste. | PENDIENTE |

## Plan seguro para CLIENTS-001

La asignación histórica no puede deducirse del nombre, RFC o usuario conectado. **No asignar masivamente clientes a la empresa por defecto** ni activar un `default_scope` falso que preserve exposición de datos.

1. Agregar `clients.organization_id` con referencia e índice sin truncar registros; preparar un reporte de clientes sin propietario.
2. Construir una conciliación determinista de datos históricos usando referencias confiables de `phones.organization_id` y `notes.organization_id` y otros contratos autorizados; **si existen discrepancias o no hay evidencia, mantenerlos en cuarentena para resolución supervisada**.
3. Tras conciliar, exigir tenant en altas, `index/show/update/destroy`, búsquedas y nested phones/notas; impedir asignaciones cruzadas por servidor.
4. Migrar unicidad de código y RFC a índices únicos parciales por organización, conservando protección de concurrencia.
5. Añadir regresiones de dos organizaciones, acceso directo por ID, cambio de empresa, permisos por rol, historial y restauración de datos. Validar base nueva y base histórica antes de hacer `organization_id` obligatorio.

**Criterio de aceptación:** no cerrar CLIENTS-001 ni dar por seguro el módulo hasta que los registros queden vinculados confiablemente a la organización, todos los endpoints respeten esa vinculación y pasen las pruebas de regresión multiempresa. Esta etapa está pendiente por riesgo de atribución incorrecta de datos históricos.

## Evidencias de verificación

- **PASÓ** [Clients CI #42645858299](https://github.com/AliRodri1992/sales_point/actions/runs/42645858299): **50 ejemplos, 0 fallos**, y RuboCop del módulo aprobado. Includes modelo, listado, filtros, notas, CRUD, errores por campo, render y escenarios Chrome.
- **PASÓ** auditoría general I18n/YAML y análisis de seguridad en commits del rediseño (el resultado se atribuye a los SHA verificados, no al estado permanente del repositorio).
- **CI global:** RuboCop sigue detectando incidencias en archivos externos, como Inventarios, Onboarding, Compras y utilidades compartidas. El resultado global no es verde; las observaciones externas deben cerrarse en su expediente propietario.
- **PENDIENTE:** verificación visual manual independiente, accesibilidad WCAG completa, migración histórica de CLIENTS-001, resolución de hallazgos bloqueantes, CI global verde y revisión/aceptación del SHA final.

## Dictamen

**Implementación visual y funcionalidades principales verificadas en CI focalizado. NO CERRADO y NO APROBADO para aislamiento multiempresa.** No fusionar a `development` mientras exista CLIENTS-001 sin cierre ni pruebas que lo respalden.

[Estándar modular](../module-quality-standard.md) · [Índice](README.md).
