# Registro de calidad — Unidades de medida (Delta POS)

- **Alcance:** exclusivamente `/admin/units_of_measure` y su relación con `sat_unit_keys`. Listado, modales, validaciones, permisos, filtros, baja lógica y administración por organización.
- **Fuera de alcance:** Productos, Presentaciones, Inventario, conversiones comerciales y cualquier asociación nueva hacia Productos. No se modificó el modelo `Product`.
- **Rama:** `feature/fixes`. **SHA inicial:** `985c26e6d9932e91246bc76c475d96bbd9c2dfd0`.
- **Método:** AI Dev Suite — `ui-ux-pro-max`, `impeccable-audit` y `ponytail-engineering`.
- **Estado:** implementación, migración limpia, RSpec focalizado, RuboCop focalizado y flujos básicos de navegador **PASARON** en `9e81ac3`. CI global y aceptación visual independiente **PENDIENTES / CON FALLOS EXTERNOS**. **NO CERRADO**.

## Alcance funcional implementado

- Campos de captura: código interno, nombre, abreviatura, descripción, unidad SAT, precisión decimal y estado.
- La precisión decimal de 0 a 6 determina si se permiten fracciones; no hay un interruptor contradictorio.
- Catálogo `units_of_measure` por organización, con referencia a `sat_unit_keys`, unicidad de código sin considerar mayúsculas y validaciones de modelo y base de datos.
- Pantalla principal con búsqueda, filtros por estado, SAT y fracciones; paginación según preferencias, indicadores resumidos y diseño adaptable.
- Alta y edición en modal Turbo; detalle en modal; baja lógica con confirmación SweetAlert2 y retroalimentación localizada.
- Autorización Pundit, seis permisos granulares, traducciones `es/en/ko`, rastreo PaperTrail y pruebas de modelos y requests agregadas.

## Hallazgos y seguimiento permanente

| ID | Prioridad | Riesgo / área evaluada | Adecuación | Verificación |
|---|---|---|---|---|
| UOM-001 | P1 | Nuevo recurso sin dueño en registro de calidad modular bloqueaba CI de I18n | Registro, ruta y expediente publicados | PASÓ auditoría I18n y YAML en CI #42634181504 |
| UOM-002 | P1 | Posible acceso cruzado entre empresas | Scope por `organization_id`, request de aislamiento y unicidad por empresa | PASÓ request de aislamiento en focalizado #42634181533 |
| UOM-003 | P1 | Claves SAT retiradas o fuera de vigencia | Solo permitir asociar claves `SatUnitKey.current` en nuevas asociaciones | PASÓ rechazo de clave caducada; borrado SAT requiere test adicional |
| UOM-004 | P2 | Inconsistencias visuales y de interacción | Modal Stimulus, dropdown Delta, errores por campo y skeleton | PASÓ Chrome: CRUD y geometría 320/390/768/1440; WCAG manual pendiente |
| UOM-005 | P2 | Entradas duplicadas y códigos inconsistentes | Normalización, modelo e índice único parcial PostgreSQL | PASÓ modelo y migración limpia; concurrencia real pendiente |
| UOM-006 | P2 | Integridad de precisión y baja lógica | CHECK decimal/estado, `deleted_at`, PaperTrail | PASÓ modelos y baja lógica; rastreo PaperTrail no probado aisladamente |
| UOM-007 | P2 | Traducciones o etiquetas incompletas | Locales es, en y ko | PASÓ paridad I18n; traducción semántica manual pendiente |
| UOM-008 | P2 | Permisos de lectura y escritura por rol | `CatalogPolicy` + códigos `units_of_measure.*` | PASÓ acceso denegado y rol autorizado; matriz granular completa pendiente |

### UOM-009 · P1 · Compatibilidad de esquema histórico
- **Hallazgo confirmado por RSpec focalizado:** `db:drop db:create db:migrate` cargó el esquema previo y marcó como aplicada la versión antigua de creación de `units_of_measure` sin crear la tabla, provocando `PG::UndefinedTable`.
- **Adecuación:** incluir el nuevo catálogo en `db/schema.rb`, conservar la migración junto a Productos y añadir migración defensiva `20261110130100` para bases ya migradas sin tabla.
- **Verificación:** PASÓ preparación desde cero y batería focalizada en #42634181533; actualización de una base legada ya desplegada aún pendiente de prueba independiente.

## Auditoría de reglas de estatus — 2026-11-09

**Base revisada:** `29278fd120329cea35f5da723d012f54bd07eae8`. **Método:** AI Dev Suite / Impeccable, UI UX Pro Max y Ponytail, con revisión estática de código y evidencia de GitHub Actions. No se ejecutó auditoría visual manual ni se probaron estos hallazgos de transición en entorno Rails. Se respetó el límite del módulo; no existen cambios nuevos en Productos.

**Política esperada:** crear en Activo por defecto; permitir Activo ↔ Inactivo; Inactivo conserva datos y no debe estar disponible para nuevas asociaciones futuras; al reactivar exigir clave SAT vigente; SAT expirado no debe alterar automáticamente el estatus interno; la baja lógica es distinta de Inactivo y exige autorización, confirmación, actor/fecha e historial.

| ID | Gravedad | Evidencia del código y efecto | Corrección / prueba requerida | Estado |
|---|---|---|---|---|
| UOM-010 | **P1** | `app/models/unit_of_measure.rb`: la validación fiscal solo se ejecuta en registros nuevos o cuando cambia `sat_unit_key_id`. La transición `inactive → active` con clave SAT vencida queda sin validación. | Validar también reactivaciones; error en Unidad SAT; specs de clave vigente, caducada y eliminada, incluidas solicitudes PATCH. | **RESUELTO**. `UnitOfMeasure#requires_current_sat_unit_key?` exige clave vigente también cuando cambia `inactive → active`; la reactivación caducada falla sin alterar el registro. RSpec modelo, request y Chrome aprobados. |
| UOM-011 | **P1** | `_list.html.erb` y `_show.html.erb` muestran únicamente estado interno y clave fiscal, sin estado de vigencia SAT. Un registro `active` con clave posteriormente vencida se presenta sin advertencia. | Badge fiscal independiente «SAT no vigente», sin desactivar la unidad; detalle y filtros de incidencias si resulta útil. | **RESUELTO**. Badge ámbar «SAT no vigente» separado del estatus interno en tabla, detalle y edición; indicador de incidencias en panel, sin cambiar automáticamente la unidad. |
| UOM-012 | **P2** | `app/controllers/concerns/admin/units_of_measure_listing.rb` usa `SatUnitKey.current` para opciones de filtro, omitiendo claves SAT vencidas que aún referencian unidades existentes. | Incluir claves asociadas a unidades de la empresa incluso si están vencidas; señalizarlas como no vigentes; prueba de filtro histórico. | **RESUELTO**. Filtro por SAT incluye las claves vinculadas a esta empresa, aunque hayan caducado o sido dadas de baja; filtro de vigencia fiscal y pruebas de aislamiento histórico aprobadas. |
| UOM-013 | **P1** | `spec/models/unit_of_measure_spec.rb`, `spec/requests/admin/units_of_measure_spec.rb` y `spec/features/units_of_measure_browser_spec.rb` cubren creación, edición y expiración en alta, pero no `active → inactive → active`, reactivación inválida ni diferencia estatus/baja. | Incorporar matriz de transición y no regresión en modelo, requests y navegador; probar que no se altere `deleted_at` al inactivar. | **RESUELTO**. Matriz de transición activa/inactiva, clave SAT vencida y retirada, actualización de fecha de baja y regresión de modal. Modelos + requests + Chrome aprobados. |
| UOM-014 | **P2** | `destroy` establece `deleted_at`; el modelo tiene PaperTrail. No hay en el controlador del módulo un registro explícito del actor o motivo de baja, y el expediente anterior no acredita dicha atribución. | Verificar `whodunnit` de PaperTrail para cambios y baja con usuario real; establecer motivo obligatorio solo si se confirma como regla global del sistema; prueba audit trail. | **RESUELTO**. `PaperTrail.request(whodunnit: current_user.id.to_s)` en create/update/destroy; prueba verifica el actor y que `deleted_at` se conserva en la baja lógica. |
| UOM-015 | **P2** | La tabla solo muestra el botón destructivo «Dar de baja» y el formulario permite «Inactivo». No hay explicación visible de la diferencia entre suspender y retirar, ni advertencia sobre SAT vencido. | Mensaje contextual y ayuda breve, confirmación SweetAlert2 conservando la identidad Delta POS; comparar con Sucursales. | **RESUELTO**. Explicación contextual de estado y baja en formulario y detalle, alerta fiscal visible y confirmación SweetAlert de «Retirar», con nombre del registro y traducciones es/en/ko; prueba Chrome comprueba cancelar sin borrar y confirmar la baja. |
| UOM-016 | **P3** | `load_sat_keys` materializa todo `SatUnitKey.current.order(:code).to_a` y el form renderiza todas las opciones. No se midió coste real con volumen SAT. | Medir render y usabilidad de búsqueda; considerar carga acotada si los datos demuestran necesidad; no introducir nuevas dependencias preventivas. | **EVALUADO Y MITIGADO**. Se probó render de clave SAT y búsqueda local con 350 entradas nuevas en Chrome, sin errores. No se introdujo una carga remota que duplicara complejidad; monitorizar volumen real y latencia antes de alterar el dropdown existente. |

**Controles sanos verificados en código:** enum `active/inactive` con default `active`; `deleted_at` como baja independiente; `sat_unit_keys` como referencia oficial; validación de vigencia en nuevas asociaciones SAT; índice único parcial por empresa y código; formularios sin HTML5 `required`; acceso Pundit y aislamiento por organización; listado paginado. No se ha conectado con Productos.

**Evidencia automatizada previa:** [Units of measure CI #42635319602](https://github.com/AliRodri1992/sales_point/actions/runs/42635319602), 15 ejemplos / 0 fallos. Esa ejecución **no** cubre la regla de reactivación; el hallazgo UOM-010 es consistente con ella. En el mismo SHA, CI global #42635319559 tiene fallos en RuboCop y RSpec; seguridad, traducciones y migraciones en limpio aprobaron. No atribuir fallos externos al catálogo sin evidencia.

**Condición de cierre:** atender P1, añadir regresiones explícitas, verificar baja y autoría, realizar inspección visual real (320/390/768/1440, 200 % zoom, teclado y lector de pantalla) y contrastar con el diseño de Sucursales. Estado **NO CERRADO**.

### Cierre técnico de hallazgos UOM-010 a UOM-016 — 2026-11-09

**Resultado:** los siete hallazgos se atendieron dentro del alcance del módulo. Referencia principal de código: `56be0039ad08e1fad452881201baf56931284921` en `feature/fixes`.

- **Evidencia focalizada:** [Units of measure CI #42641233789](https://github.com/AliRodri1992/sales_point/actions/runs/42641233789) — **30 ejemplos / 0 fallos**, incluyendo Chrome en alta, edición, filtro SAT histórico, reactivación bloqueada por clave caducada, confirmación SweetAlert (cancelar y retirar), búsqueda con 350 claves adicionales y diseño de modal a 320/390/768/1440. RuboCop de Unidades de medida pasó.
- **Internacionalización:** [Languages CI #42641233721](https://github.com/AliRodri1992/sales_point/actions/runs/42641233721) — aprobado para textos es/en/ko y paridad lingüística.
- **Auditoría y datos:** PaperTrail conserva `whodunnit` en las tres operaciones; la baja marca `deleted_at` sin modificar el estado interno; las referencias SAT retiradas siguen disponibles para consulta histórica.
- **Rendimiento:** escenario de búsqueda con 350 registros SAT adicionales pasó; no es una medición de producción ni garantiza rendimiento con cientos de miles de claves. La optimización asíncrona no se justifica todavía.
- **Sin relación con Productos:** no se añadieron referencias, modelos ni mutaciones en Productos o Presentaciones.
- **Aún pendiente del estándar general:** revisión visual independiente comparada con Sucursales, comprobación manual de accesibilidad (zoom 200 %, lector de pantalla, teclado completo), y CI global verde. Los fallos externos de CI no son aceptación del catálogo.

**Resultado de la auditoría focalizada:** UOM-010 a UOM-015 resueltos; UOM-016 evaluado y mitigado. **Expediente modular: NO CERRADO** hasta satisfacer criterios externos de aceptación.

## Evidencias y límites

- **PASÓ:** [Units of measure CI #42634181533](https://github.com/AliRodri1992/sales_point/actions/runs/42634181533) en SHA `9e81ac30f9f76ca5c156e902d85a8ec4279d8d0e`: 15 ejemplos (modelos + solicitudes + navegador Chrome), 0 fallos; RuboCop focalizado aprobado. Se verificaron altas, errores, consulta, edición y cierre con Escape, además de límites del panel en 320/390/768/1440 px.
- **FALLÓ inicialmente:** CI #42625619635 (`Rails I18n and YAML audit`) y Languages CI #42625619623 (`Languages locale integrity`) por `Unowned admin resource: units_of_measure`. Se añadió este registro para corregir la causa. No equivale a comprobar que CI ya pasó.
- **PASÓ:** controles transversales de seguridad e I18n/YAML; migraciones en CI fresco para SHAs anteriores y batería focalizada con base reconstruida. **CI global** #42634181504 sigue fallando RuboCop por infracciones de otros módulos. La falla histórica de RSpec en Clientes (`GET /admin/clients` devuelve 403 frente a 200 esperado) está fuera del límite propio de Unidades.
- **PENDIENTE:** verificación manual visual y accesibilidad en navegador (zoom 200 %, lector de pantalla, contraste y manejo completo del foco), evidencia de migración desde base antigua en producción, revisión independiente y CI global verde.
- **Revisión independiente y responsable de aceptación:** PENDIENTES.

## Criterio de cierre

Mantener **NO CERRADO** hasta que todas las comprobaciones del estándar estén verdes, los hallazgos tengan regresiones y se haya realizado la auditoría visual real. Ninguna modificación implica aceptación automática ni fusión a `development`.

[Estándar modular](../module-quality-standard.md) · [Índice](README.md).

## Reauditoría focalizada — 2026-11-09 (estado de filtros y teclado)

**Base auditada:** `b4bebde435ff54a27abb9c4ef9799f4ef1bb7d9b` en `feature/fixes`. **Método:** AI Dev Suite (`impeccable-audit`, `ui-ux-pro-max`, `ponytail-engineering`), lectura estática del código y comprobación de GitHub Actions. Alcance limitado a `/admin/units_of_measure` y contratos de UI compartidos usados por sus pantallas; **no se relaciona con Productos**. Se conservaron los IDs UOM-001 a UOM-016 y su historial.

| ID | Gravedad | Propiedad | Evidencia y reproducción razonada | Adecuación y regresión requerida | Estado |
|---|---|---|---|---|---|
| **UOM-017** | **P2** | Propio (Turbo, controlador y vistas) | En `index.html.erb` los filtros están fuera de `turbo-frame#units_of_measure_list`. Los enlaces de edición y los formularios no incluyen los parámetros actuales del listado; `saved_unit` vuelve a ejecutar `load_units` con los parámetros de la operación y `create/update/destroy.turbo_stream.erb` sustituyen únicamente estadísticas y tabla. Tras guardar desde un listado filtrado o paginado pueden permanecer controles y URL antiguos mientras la tabla vuelve a condiciones predeterminadas. **Confirmado por trazado de código; no reproducido aún en navegador.** | Preservar o restablecer coherentemente `search`, `status`, `sat_unit_key_id`, `fractional`, `sat_health`, `sort`, `direction` y `page` tras el CRUD; cubrir alta, edición y baja desde página filtrada/ordenada con Capybara Chrome, incluyendo resultados vacíos. | **ABIERTO — sin corrección ni regresión ejecutada** |
| **UOM-018** | **P2** | Integración UI compartida (`delta_select_controller.js` ↔ modal de Unidades) | `delta_select_controller.js` maneja `Escape` cerrando el dropdown pero no detiene su propagación. En `admin_dashboard.html.erb`, el modal de Unidades escucha `keydown.esc@window->modal#close`. La misma pulsación puede cerrar también el modal, perdiendo la edición no guardada. **Flujo confirmado por código; falta reproducción independiente Chrome.** | Al tener un dropdown abierto, primer Escape debe cerrar solo el dropdown y conservar el modal; segundo Escape debe cerrar el modal. Ajuste del contrato compartido con tests del módulo y regresiones en consumidores del dropdown. No modificar otros módulos salvo la corrección mínima del componente común. | **ABIERTO — sin corrección ni regresión ejecutada** |

### Estado de verificación de esta pasada

- **Focalizada en SHA base:** [Units of measure CI #42642541300](https://github.com/AliRodri1992/sales_point/actions/runs/42642541300) **PASÓ**: jobs `Units of measure RuboCop` y `Units of measure model and request regressions` (incluida preparación `db:drop db:create db:migrate` y navegador Chrome). Estas pruebas **no cubren UOM-017 ni UOM-018**.
- **Global en SHA base:** [CI #42642541385](https://github.com/AliRodri1992/sales_point/actions/runs/42642541385) **EN EJECUCIÓN al momento de la consulta**; volver a comprobar resultado final. Un CI posterior a este registro documental debe validarse con su propio SHA.
- **Pendiente:** reproducción en navegador de UOM-017 y UOM-018, corrección y pruebas; revisión visual independiente con 320/390/768/1440, zoom 200 %, recorrido completo con teclado, lector de pantalla y contraste. Base legada con migración de reparación sin validación independiente.
- **Dictamen:** sin P0/P1 nuevos identificados en la lectura estática; **2 P2 nuevos abiertos**, sin aceptación formal. **MÓDULO NO CERRADO** según el estándar de calidad modular. Esta auditoría no modifica código de producto.

### Adecuaciones UOM-017 y UOM-018 — implementación 2026-11-09

- **UOM-017 — IMPLEMENTADO, PENDIENTE DE VERIFICAR:** el listado publica su consulta efectiva (filtros, orden, página normalizada y tamaño), el controlador Stimulus `units-of-measure-context` la añade al envío Turbo de formularios, y la baja lógica usa el mismo contexto en la URL. Las redirecciones HTML también conservan los parámetros, y el frame solicita `turbo-action=advance` para mantener el historial de navegación. Las nuevas regresiones request y Chrome cubren creación y edición filtradas, eliminación desde la última página y ordenación.
- **UOM-018 — IMPLEMENTADO, PENDIENTE DE VERIFICAR:** el dropdown Delta solo consume Escape cuando su lista está abierta y no propaga el evento al modal; si ya está cerrado, Escape sigue llegando al modal. Una regresión Chrome comprueba dos Escape consecutivos y la conservación de los datos antes de cerrar.
- **Verificación:** la ejecución focalizada del SHA que publica estos cambios sigue **PENDIENTE**. Conservar los IDs e historial previo hasta confirmar resultados. CI global, revisión independiente de accesibilidad y migración sobre una base histórica son puertas de cierre separadas.

## Reauditoría de adecuaciones — segunda pasada 2026-11-09

**Rama y SHA funcional auditado:** `feature/fixes`, `79d03fccf305a3ddf4f12a13b17b8c3dafc67449`. Confirmado mediante lectura de archivos y los logs de GitHub Actions; el HEAD `f4af7f7f8339bacf79c42b3cefa596136ef6b4d9` solo cambia un spec de Clientes respecto de ese commit, no el código de Unidades. Método AI Dev Suite (`impeccable-audit`, `ui-ux-pro-max`, `ponytail-engineering`). Esta es una **reauditoría**, no una aprobación; sin inspección interactiva independiente en entorno local.

| ID permanente | Prioridad | Evidencia | Tratamiento / prueba | Estado |
|---|---|---|---|---|
| **UOM-019** | **P1 — BLOQUEANTE PARA ACEPTACIÓN** | [Units of measure CI #42645721206](https://github.com/AliRodri1992/sales_point/actions/runs/42645721206) **FALLÓ** en ambos jobs. El spec `spec/requests/admin/units_of_measure_spec.rb`, líneas 181–192, no es parseable: Ruby emite `SyntaxError` en línea 184 y RuboCop `Lint/Syntax` en líneas 184, 189 y 192, por el uso ambiguo de argumentos `headers:` sin paréntesis en solicitudes con argumentos keyword. El job RSpec informa `18 examples, 0 failures, 1 error occurred outside of examples` y por tanto **no valida** las nuevas regresiones. Además RuboCop informa `Layout/FirstArgumentIndentation` y `Layout/HashAlignment` en `units_of_measure_controller.rb` líneas 96/98 y `Layout/EmptyLinesAroundBlockBody` en browser spec línea 251. | Arreglar el spec con `headers: headers` y/o llamada parentizada sin ambigüedad; corregir layout de controlador y spec. Repetir sintaxis, RuboCop y **todos** los specs de modelo, request y Chrome en el mismo SHA; no declarar UOM-017/018 verificadas antes. | **ABIERTO — CONFIRMADO EN CI** |
| **UOM-017 (ampliación del mismo ID)** | **P2** | Se añadió `data-list-query` y propagación de contexto, pero cuando la baja elimina el último registro de una página, `paginate_units` normaliza `@current_page` y las respuestas `destroy.turbo_stream.erb` actualizan solo tabla y estadísticas. **La URL del navegador no se actualiza en ese Turbo Stream**; puede continuar con `page=2` cuando la tabla ya está en `page=1`. La nueva prueba comprueba `data-list-query` pero **no `current_url` ni navegación atrás/adelante**. Evidencia de código; interacción en navegador por confirmar. | No abrir un hallazgo duplicado: extender UOM-017 con sincronización explícita de URL, página efectiva y filtros tras CRUD y casos de history back/forward, incluyendo página vacía. | **IMPLEMENTADO PARCIAL — REQUIERE REPRODUCCIÓN Y REGRESIÓN** |
| **UOM-018 (reevaluación)** | **P2** | `delta_select_controller.js` ahora detiene Escape solamente cuando el menú está abierto y la nueva prueba Chrome contempla Escape secuencial, pero RSpec se interrumpió antes de acreditar dicha prueba en el SHA. | Repetir escenario Chrome y prueba de teclado; comprobar compatibilidad mínima con otros consumidores del dropdown compartido. | **IMPLEMENTADO — NO VERIFICADO EN CI ACTUAL** |

**Estado de CI:** workflow focalizado #42645721206 = **FALLÓ** (RSpec y RuboCop). CI global #42645721410 en el mismo SHA = **CANCELADO**; no acredita aceptación. La CI del nuevo HEAD `f4af7f7` estaba en ejecución al consultar. El historial anterior de UOM-001 a UOM-016 permanece intacto.

**Otras puertas pendientes:** accesibilidad manual (foco, Tab/Escape, zoom 200 %, lector de pantalla y contraste), revisión visual independiente (320/390/768/1440), actualización de esquema histórico en una base legada real, CI global verde y aceptación del responsable. No modificar Productos ni otros módulos por este diagnóstico. **Dictamen: NO CERRADO**.

### Continuación de adecuaciones UOM-017/018/019 — 2026-11-09

- **UOM-019 (P1) — CORRECCIÓN IMPLEMENTADA, PENDIENTE DE CI:** se corrigió el `SyntaxError` de `spec/requests/admin/units_of_measure_spec.rb`, pasando explícitamente el argumento `headers: headers`. También se ajustó el formato RuboCop del controlador y del spec Chrome. Se sustituyó una aserción ambigua de texto por un nombre específico para evitar coincidencias dentro de `INACTIVE`. Es necesario obtener RuboCop y RSpec focalizados en verde antes de pasar a `VERIFICADO`.
- **UOM-017 (P2) — CORRECCIÓN COMPLETADA EN CÓDIGO, PENDIENTE DE CI/NAVEGADOR:** al reemplazar el listado por Turbo Stream, el controlador `units-of-measure-context` sincroniza la URL de la página y los filtros efectivos (incluyendo el número de página normalizado) mediante `history.replaceState`, preservando el estado de historial de Turbo. La regresión Chrome comprueba `current_url` después de retirar el último registro de una página.
- **UOM-018 (P2) — CORRECCIÓN ANTERIOR CONSERVADA:** Escape cierra el dropdown abierto sin propagarse al modal; la regresión de navegador espera que otra pulsación cierre el modal. Los resultados de CI del nuevo commit son los que acreditarán este comportamiento.
- **Puertas de cierre:** matriz completa de pruebas RSpec/RuboCop, CI global, revisión manual de accesibilidad (zoom 200 %, lector de pantalla, contraste), inspección visual independiente y actualización comprobada de una base histórica. No se toca Productos ni se realiza merge.

### Evidencia CI posterior a las correcciones — 2026-11-09

**SHA de código probado:** `c7c2868a9e59f2563cb1d0960aae134e2bfcc499`. [Units of measure CI #42654122312](https://github.com/AliRodri1992/sales_point/actions/runs/42654122312) — **SUCCESS** en los dos jobs: `Units of measure RuboCop` y `Units of measure model and request regressions`. El log RSpec acredita **34 ejemplos, 0 fallos** (modelo, aislamiento organizacional, solicitudes HTTP y navegador Chrome); la preparación reconstruyó la base de pruebas mediante `db:drop db:create db:migrate`.

- **UOM-019 — VERIFICADO para el código probado:** se corrigieron los errores de sintaxis y las ofensas RuboCop; el spec nuevo carga y termina en verde. Sin P1 propio abierto a partir de esta evidencia.
- **UOM-017 — VERIFICADO en escenarios focalizados:** se comprobaron filtros al crear y editar, baja lógica desde la última página, el retorno a página válida y la sincronización `current_url` con la consulta aplicada. La comprobación manual adicional de historial atrás/adelante no está acreditada.
- **UOM-018 — VERIFICADO en escenario focalizado Chrome:** al pulsar Escape con el dropdown SAT abierto, se cierra solo ese desplegable, se conservan datos del formulario y una pulsación posterior cierra el modal.
- **CI global:** continúa siendo una puerta de aceptación independiente. El RuboCop global del mismo SHA reportó infracciones en archivos externos al módulo (inventarios, onboarding, otros servicios/specs y scripts), no en los archivos Ruby del catálogo. La CI global no se considera verde sin todos sus jobs.
- **Cierre global NO ACREDITADO:** faltan revisión visual independiente, zoom 200 %, contraste/lector de pantalla, migración comprobada desde una base histórica existente y CI global satisfactoria. No se fusionaron ramas ni se relacionaron Productos.

**Estado de seguimiento:** los defectos UOM-019 y los escenarios automatizados UOM-017/UOM-018 se atendieron con evidencia focalizada; el módulo completo permanece **NO CERRADO** hasta superar las puertas generales.

### UOM-020 · P1 · Error de ruta al renderizar el sidebar en Categorías — 2026-11-09

- **Síntoma recibido:** `ActionController::UrlGenerationError` desde `app/views/admin/shared/_sidebar.html.erb:200` durante `Admin::Categories#index`. El helper `admin_units_of_measure_path` intentó generar una acción `show` sin `:id`.
- **Diagnóstico del código:** `resources :units_of_measure` usa la inflexión especial `unit_of_measure → units_of_measure` definida en `config/initializers/inflections.rb`. Si el servidor Puma estaba iniciado antes de cargar esa regla, conserva las rutas antiguas; esta hipótesis requiere comprobar `bin/rails routes -g units_of_measure` dentro del contenedor que sirve la página. No se ha demostrado un defecto nuevo en `CategoriesController`.
- **Medida operativa recomendada:** reiniciar solo el servicio Rails con `docker compose -f docker-compose.dev.yml restart web`, sin borrar bases de datos. Confirmar que `admin_units_of_measure` apunta a `index` sin `:id` y `admin_unit_of_measure` a `show` con `:id`.
- **Regresiones añadidas:** prueba de solicitud real a `/admin/categories` con permiso de Unidades de Medida, verificando que el sidebar enlace al listado; prueba del router Rails que reconoce `index` frente a `show`. Las verificaciones automatizadas del nuevo commit quedan **PENDIENTES DE CI** y no sustituyen reiniciar el proceso que reportó el error.
- **Alcance:** sin cambios en Productos, base de datos ni reglas de permisos. El expediente sigue **NO CERRADO** hasta validar el servidor real y completar las puertas anteriores.
