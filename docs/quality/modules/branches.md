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