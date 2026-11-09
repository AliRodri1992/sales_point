# Registro único de calidad: Plantillas de correo electrónico

> **Estado: IMPLEMENTADO, PENDIENTE DE CIERRE INTEGRAL.** Este registro es la referencia de las siguientes auditorías del módulo: actualizar los mismos ID, no volver a presentarlos como fallas nuevas. El estándar obligatorio está en [calidad modular](../module-quality-standard.md).

- **Módulo:** Plantillas de correo, Remitentes e Identidad visual.
- **Rutas principales:** `/admin/email_templates`, vista previa, historial, edición/publicación, remitentes e identidad visual.
- **Rama:** `feature/fixes`; **SHA base de esta revisión:** `b727fa9c5c17daf7b3a063dc03211da6a996fcde`.
- **SHA con correcciones y pruebas del módulo:** `9c214de97e7ef2a8481810a8c3e4787c083bf90d`.
- **SHA de aceptación:** PENDIENTE. **Estado:** IMPLEMENTADO, PENDIENTE DE VERIFICACIONES EXTERNAS Y CI GLOBAL.
- **Fuera de alcance:** fallos internos de Onboarding, Catálogos y otros módulos; se informa su impacto en la puerta de CI general.

## Mapa de alcance

| Pantalla o flujo | Componentes / servicios | Pruebas automatizadas |
|---|---|---|
| Catálogo, filtros, tabla móvil | `EmailTemplatesQuery`, vista `_list`, acciones | `spec/requests/admin/email_templates_spec.rb`, `spec/features/email_template_creation_workflow_spec.rb` |
| Alta, borrador, publicación, versiones y reactivación | `EmailTemplate`, `EmailTemplateVersion`, controladores | Specs de modelos, solicitudes y navegador |
| Vista previa y variables | `Renderer`, `SampleData`, `email_template_preview_controller.js` | Specs de renderer, requests y navegador |
| Remitentes y branding | `Sender`, `Branding`, modelos de configuración, vistas | Specs de servicios/modelos y `email_setting_audits_spec.rb` |
| Entrega real, correo de prueba y auditoría | `DeliveryJob`, `TestDeliveryJob`, mailers | Specs de trabajos y mailers |
| Traducciones es/en/ko | `config/locales/email_templates.*.yml` | `Email Templates CI > Email locale integrity and translation parity` |

## Registro persistente de hallazgos

| ID | Prioridad | Evidencia / causa raíz | Corrección / pruebas | Estado |
|---|---|---|---|---|
| EM-001 | P1 | `sender_verification_disclaimer` duplicado en tres YAML; el CI especializado anterior no validaba YAML | Eliminación de duplicados + nueva puerta estricta de i18n | **VERIFICADO** — [CI con auditoría YAML](https://github.com/AliRodri1992/sales_point/actions/runs/42549560849) |
| EM-002 | P1 | `www.example.com` podía utilizarse como host de respaldo en producción | Bloqueo de dominios reservados en configuración y branding + specs | **VERIFICADO** — [CI](https://github.com/AliRodri1992/sales_point/actions/runs/42550340295) |
| EM-003 | P1 / externo | `Sender.verified?` utiliza estado guardado, no verificación independiente DNS/proveedor | Ajuste de mensajes es/en/ko; no se permite forjar estado desde formulario | **ABIERTO: integración con proveedor y DNS** |
| EM-004 | P1 / integración | Reintentos de errores ambiguos pueden duplicar envíos SMTP; SMTP no garantiza idempotencia | Limitar reintentos automáticos a fallos previos a aceptación y probar ambos trabajos | **MITIGADO**, pendiente idempotencia proporcionada por integración; [CI](https://github.com/AliRodri1992/sales_point/actions/runs/42551159288) |
| EM-005 | P2 | Errores del formulario renderizados por servidor y JS al mismo tiempo | Evitar mensajes repetidos, conservar `aria-invalid` y cobertura en navegador | **VERIFICADO** — [CI](https://github.com/AliRodri1992/sales_point/actions/runs/42533858646) |
| EM-006 | P2 | Aviso de verificación del dominio repetido en dos secciones de Remitentes | Un solo aviso en sección de verificación + spec | **VERIFICADO** — [CI](https://github.com/AliRodri1992/sales_point/actions/runs/42550340295) |
| EM-007 | P2 | Faltaba regresión específica para reactivar una plantilla publicada previamente y archivada | Prueba del ciclo archivado → borrador → republicación, sin perder historial | **VERIFICADO** — [CI](https://github.com/AliRodri1992/sales_point/actions/runs/42550340295) |
| EM-008 | P2 / externo | Compatibilidad real Gmail y Outlook no ejercitada | Requiere correos reales y pruebas de cliente | **NO VERIFICADO** |
| EM-009 | P2 / manual | Zoom 200 %, lector de pantalla y teclado integral no comprobados en todos los navegadores | Pruebas Capybara parciales; validación manual pendiente | **NO VERIFICADO** |
| EM-010 | Integración | CI global puede fallar por Ruby/RSpec de otros módulos | No atribuir al módulo; conservar evidencia del job y SHA | **BLOQUEA CIERRE GLOBAL SI NO APRUEBA** |

## Puertas de aceptación

- [x] Las validaciones del servidor y sus mensajes por campo tienen cobertura focalizada.
- [x] RSpec de Plantillas, Ruby y flujos de navegador aprobados: **262 ejemplos, 0 fallos** en [Email Templates CI](https://github.com/AliRodri1992/sales_point/actions/runs/42551159288).
- [x] RuboCop especializado aprobado en esa misma ejecución.
- [x] YAML y paridad es/en/ko comprobados en CI especializado y en auditoría general de traducciones.
- [x] Vistas previas distinguen enlaces ficticios de envíos reales.
- [x] Estado publicado/archivado y acciones de reactivación tienen regresiones.
- [ ] CI global completo aprobado en el SHA de aceptación.
- [ ] Proveedor de correo y SPF/DKIM/DMARC comprobados de forma real.
- [ ] Semántica de envío único acordada con proveedor y probada ante resultado ambiguo.
- [ ] Comprobación real de Gmail, Outlook, teclado, foco, lector de pantalla y zoom 200 %.

## Regla para futuras auditorías

1. Antes de abrir un hallazgo, comprobar si coincide con uno de los ID existentes y ampliar su evidencia.
2. Distinguir fallo reproducido, inferencia estática y verificación externa pendiente.
3. Toda corrección propia requiere prueba de regresión, CI especializado completo e i18n estricto.
4. No utilizar `CERRADO` ni `100 %` mientras haya pendientes de integración/UX o CI general rojo.
5. Evitar atribuir a Plantillas errores exclusivos de otros módulos: registrar dependencia y propietario.

**No se ha fusionado la rama.** Los controles externos requieren un proveedor/entorno de correo operativo y acceso a clientes reales.


<!-- Canonical record consolidated from legacy `email_templates.md` on 2026-11-08. Historical IDs EM-001..EM-010 preserved. -->

## Reauditoría 2026-11-08 — AI Dev Suite y estándar modular

**Método:** aplicación guiada de Impeccable Audit (estados, foco y errores), UI UX Pro Max (formularios, accesibilidad y consistencia) y Ponytail Engineering (contratos, integridad y regresiones). Se revisó el código disponible en GitHub; no se ejecutaron las CLI externas de estos proyectos.  
**Rama:** `feature/fixes`. **SHA de código inspeccionado:** `0b7491bbbbaf0a625fb75738a17695ed05284200` (los archivos funcionales del módulo no cambiaron en la comparación desde `9c214de97e7ef2a8481810a8c3e4787c083bf90d`). **SHA de aceptación:** PENDIENTE.  
**Alcance:** rutas propias de plantillas, versiones, previsualización, comparación, borrador/publicación, catálogo, remitentes y branding; modelos, autorización, servicios de entrega, renderización, vistas, Stimulus, specs, migraciones y locales. Las entregas reales, SPF/DKIM/DMARC y Gmail/Outlook son contratos externos, no auditoría interna de otros módulos.

### Hallazgos nuevos, no equivalentes a los históricos

| ID | Prioridad / clase | Hallazgo y evidencia concreta | Causa raíz y prueba exigida | Estado |
|---|---|---|---|---|
| EM-011 | P2 / PROPIO | En el editor, al recibir 422, los errores renderizados por servidor pueden permanecer visibles aunque el usuario corrija el campo y la siguiente vista previa responda 200. `app/javascript/controllers/email_template_preview_controller.js` elimina solo `[data-email-preview-field-error]` y no invalida mensajes `[data-server-field-error]`; la spec existente `spec/features/email_template_creation_workflow_spec.rb` comprueba que no se dupliquen, pero no que desaparezcan cuando dejan de aplicar. | Separar mensajes persistentes del último guardado y resultado vigente de la validación por vista previa; borrar/reemplazar errores obsoletos sin duplicación ni engañar al usuario. Añadir escenario 422 → corregir → 200, comprobando texto, `aria-invalid`, `aria-describedby` y no persistencia hasta guardar. | **CONFIRMADO POR CÓDIGO; reproducción navegador pendiente** |
| EM-012 | P2 / PROPIO | La función compartida `error_message_for` genera elementos `*_error` (`app/helpers/application_helper.rb`), pero campos de `app/views/admin/email_templates/edit.html.erb`, `new.html.erb`, `app/views/admin/email_sender_settings/edit.html.erb` y `app/views/admin/email_branding_settings/edit.html.erb` asignan `aria-invalid` sin referenciar sistemáticamente el mensaje de error mediante `aria-describedby` ni anunciarlo. En Nuevo, algunos `aria-describedby` solo apuntan al texto de ayuda. | Asociar los IDs reales de ayuda y error al campo en 422, sin duplicar mensajes, y validar navegación con teclado/lector de pantalla. Añadir specs para todos los formularios con errores del modelo y regresión para múltiples errores por campo. | **CONFIRMADO POR CÓDIGO; lector de pantalla pendiente** |

### Evidencia de verificación y bloqueos

| Control | Resultado para esta reauditoría |
|---|---|
| Código y permisos | Inspección estática de políticas Pundit, scopes de organización, modelos, transiciones, índices, servicios de envío y previsualizaciones con iframe sandbox. **No equivalen a pruebas ejecutadas.** |
| CI especializado previo | [Email Templates CI #42551159288](https://github.com/AliRodri1992/sales_point/actions/runs/42551159288) **PASÓ** en `9c214de97e7ef2a8481810a8c3e4787c083bf90d`: RSpec/navegador, RuboCop especializado y paridad YAML. El expediente histórico registra **262 ejemplos, 0 fallos**. |
| Comparación entre SHAs | Desde `9c214de` hasta `0b7491b` no se modificaron archivos funcionales del módulo; hubo cambios documentales y de workflow. Esto no certifica el SHA de aceptación posterior. |
| CI global del SHA inspeccionado | [CI #42552457726](https://github.com/AliRodri1992/sales_point/actions/runs/42552457726) **CANCELADO** para `0b7491b`; no puede usarse como evidencia de éxito. |
| RSpec / RuboCop / Brakeman / YAML ejecutados en esta reauditoría | **NO EJECUTADOS** en entorno Rails local. No se atribuyen aprobaciones al presente análisis. |
| Vista real, responsive exhaustivo, 200 % de zoom, lector de pantalla | **NO EJECUTADOS** en navegador de una instancia viva. |
| SMTP real, SPF/DKIM/DMARC, Gmail/Outlook e idempotencia de proveedor | **NO VERIFICADOS**; conservar EM-003, EM-004, EM-008 y EM-009 abiertos o mitigados según su historial. |

**Dictamen:** AUDITADO POR CÓDIGO CON HALLAZGOS, **NO CERRADO**. Los hallazgos EM-011 y EM-012 requieren corrección, pruebas específicas y reevaluación; no se reabren EM-001, EM-002, EM-006 o EM-007 sin evidencia contraria. El registro se mantiene único en este documento; el anterior `email_templates.md` ya fue consolidado previamente y no se crea expediente paralelo. Las integraciones externas y CI global continúan bloqueando el cierre.


## Adecuaciones EM-011 y EM-012 — 2026-11-08

**Código implementado:** [commit 001b90d8](https://github.com/AliRodri1992/sales_point/commit/001b90d8da4afc8f76f51566ca11d256a6187c88). **Corrección de lint y registro:** en el commit que incluye esta sección. **Rama:** `feature/fixes`.

- **EM-011 — VERIFICADO POR CI ESPECIALIZADO EN `3c31725c` (lectores de pantalla manuales pendientes).** `email_template_preview_controller.js` conserva feedback mientras se valida, compara los errores Rails existentes con el 422, reemplaza los que cambian y elimina los obsoletos tras respuesta válida; sincroniza `aria-invalid`, `aria-describedby` y estilos. La spec de navegador comprueba 422 → corrección → 200, placeholders inválidos y que no se guarde contenido.
- **EM-012 — VERIFICADO POR CI ESPECIALIZADO EN `3c31725c` (lectores de pantalla manuales pendientes).** El helper de formularios asigna IDs a todos los mensajes únicos del modelo, incluidos varios por atributo, y los enlaza con ayudas de campo mediante `validation_describedby`. Aplicado a alta, borrador, remitentes, branding y correo de prueba. Specs request comprueban las asociaciones.

**Ejecución inicial:** [Email Templates CI #42555889164](https://github.com/AliRodri1992/sales_point/actions/runs/42555889164): **264 ejemplos, 0 fallos**; traducciones aprobadas. RuboCop detectó seis ofensas de estilo en nuevas pruebas, motivando este commit. [CI global #42555889141](https://github.com/AliRodri1992/sales_point/actions/runs/42555889141): seguridad e I18n aprobados inicialmente y lint fallido antes de la corrección.

**Puertas pendientes:** CI especializado y global completo en el mismo SHA de aceptación, verificación manual con lector de pantalla y zoom, contratos externos SMTP (EM-003/004/008/009). **NO CERRADO** hasta reunir evidencias.


## Reauditoría de regresiones — AI Dev Suite, 2026-11-08

**Alcance técnico:** catálogo, filtros/Turbo Frame, alta, editor de versiones y vista previa, publicación, prueba de envío, remitentes, branding, permisos, servicios/renderer y traducciones. Inspección de `feature/fixes` en el SHA `3c31725cdf41ef0c2b45caa33df6e0b3735a931d`. AI Dev Suite: heurísticas documentadas de Impeccable (estados/errores), UI UX Pro Max (semántica/responsive) y Ponytail (contratos/regresión); **no se ejecutaron CLIs externos ni prueba real de navegador o de proveedor SMTP en esta reauditoría**. Este registro amplía los IDs previos; no crea un segundo expediente.

### Resultado de las correcciones ya aplicadas

- **EM-011 — VERIFICADO en CI especializado:** conciliación de mensajes 422 con el resultado vigente de vista previa, conservación de `aria-describedby`, eliminación de mensajes obsoletos. El flujo de navegador está automatizado.
- **EM-012 — VERIFICADO en CI especializado:** IDs y asociación accesible de errores Rails, incluidos mensajes múltiples, en alta, borrador, remitentes, branding y prueba de envío.
- **Evidencia:** [Email Templates CI #42556277586](https://github.com/AliRodri1992/sales_point/actions/runs/42556277586) `success`, SHA `3c31725c`: **264 RSpec, 0 fallos**, RuboCop especializado aprobado, paridad YAML es/en/ko aprobada. La evaluación de lector de pantalla y zoom sigue en EM-009.

### Hallazgos propios nuevos (no duplicados)

| ID | Prioridad y tipo | Evidencia / causa raíz | Corrección y regresión requerida | Estado |
|---|---|---|---|---|
| **EM-013** | **P2 / funcionalidad** | `EmailTemplates::Renderer::KNOWN_VARIABLES` acepta `name`; `EmailTemplates::SampleData.call` no provee `name`. Un borrador válido con `{{name}}` no se puede previsualizar, porque `Renderer#replace` levanta `Missing email variable`. La spec `spec/requests/admin/email_templates_spec.rb` actualmente espera redirección de error para ese ejemplo, normalizando el problema. | Incorporar un valor de prueba coherente para todas las variables conocidas, en particular `name`, y cambiar la prueba para esperar vista previa exitosa sin enviar ni persistir datos. Comprobar las tres locales. | **VERIFICADO POR CI ESPECIALIZADO #42558182620**; validación manual pendiente |
| **EM-014** | **P2 / UX-filtros** | Los mensajes de fechas inválidas o rango invertido se dibujan en `app/views/admin/email_templates/index.html.erb`, **fuera** de `<turbo-frame id="email_templates_list">`. El formulario `GET` usa `data-turbo-frame="email_templates_list"`; al filtrar dentro del marco solo se reemplaza la lista, por lo que los errores nuevos del formulario no se actualizan en la pantalla. La spec actual verifica respuesta GET completa, no navegación Turbo. | Reconciliar también el formulario o manejar la navegación de filtros a nivel `_top`, conservando enfoque/búsqueda según diseño; prueba Capybara con rango inicial mayor al final y comprobación del mensaje visible bajo el campo después de filtrar. | **VERIFICADO POR CI ESPECIALIZADO #42558182620**; navegador automatizado aprobado |
| **EM-015** | **P2 / validaciones** | `EmailTemplateVersion#declared_variables` y `Renderer::VARIABLE_PATTERN` solo reconocen la sintaxis exacta `{{recipient_name}}`. Tokens mal escritos como `{{ recipient_name }}` o `{{recipient-name}}` no se detectan como inválidos y el renderer los deja literales en el correo. | Rechazar o señalar los delimitadores `{{...}}` mal formados en modelo antes de publicar, sin tratar texto ordinario como placeholder; probar borrador, vista previa, publicación y HTML/texto. | **VERIFICADO POR CI ESPECIALIZADO #42558182620**; modelo/renderer/preview |
| **EM-016** | **P1 / activación-recuperación** | `EmailTemplateVersion#validate_required_security_variable` comprueba `html_body.to_s.include?('{{activation_url}}')` o `{{recovery_url}}`. La coincidencia puede estar solo en un comentario HTML, que el `Renderer#render_html` sanitiza y elimina. Así, la publicación puede superar la regla sin que el enlace sea visible o accionable en el HTML recibido, aunque exista en texto plano. | Validar el contenido **renderizado y sanitizado** y la presencia de un enlace efectivo en `href` para plantillas críticas, además de conservar el requisito en texto plano. Añadir casos de comentario, etiqueta ocultada y enlace correcto. | **VERIFICADO POR CI ESPECIALIZADO #42558182620**; proveedor real pendiente |

### Comprobaciones de alcance y aceptación

| Área | Resultado |
|---|---|
| Modelos y CRUD | Se revisaron `EmailTemplate`, `EmailTemplateVersion`, políticas, scopes de organización y flujos de borrador/publicación/restauración; correcciones previas mantienen regresiones automatizadas. |
| Vistas/UI | Se inspeccionaron catálogo, búsqueda, filtros, alta, editor, vista previa, comparación y las pantallas de Remitentes/Branding; los hallazgos EM-013/014 requieren un caso de navegador adicional. |
| Renderizado y seguridad | Se revisaron placeholders, saneamiento HTML, URLs, cabeceras, pruebas de envío y auditoría; EM-015/016 requieren regresiones funcionales. Los contratos de proveedor siguen bajo EM-003/004/008. |
| CI especializado | **APROBADO** para el SHA auditado, [ejecución #42556277586](https://github.com/AliRodri1992/sales_point/actions/runs/42556277586). |
| CI global | [Ejecución #42556277587](https://github.com/AliRodri1992/sales_point/actions/runs/42556277587): seguridad, migraciones/semillas e I18n aprobaron; **RuboCop falló por ofensas fuera del módulo** (p. ej. `spec/services/purchases/receive_spec.rb` tiene error sintáctico y archivos de Sucursales tienen otras ofensas). RSpec global estaba en curso durante la revisión. No alterar esos módulos en esta auditoría. |
| Navegador manual / zoom 200 % / lector de pantalla / Gmail-Outlook / SMTP real | **NO EJECUTADOS**; conservar EM-003, EM-004, EM-008 y EM-009 con su estado anterior. |

**Dictamen:** EM-011/012 verificados por CI especializado; EM-013/014/015/016 pendientes de adecuación y nueva prueba. **AUDITORÍA ACTUALIZADA; MÓDULO NO CERRADO.** Solo registrar hallazgos reproducidos o demostrables, evitar reabrir IDs históricos aprobados, y no confundir aprobación del CI especializado con el cierre del sistema.



## Adecuaciones EM-013 a EM-016 — implementación

- **EM-013 — VERIFICADO POR CI ESPECIALIZADO:** conjunto de datos de ejemplo ahora cubre `name` en es/en/ko; la prueba antes normalizaba el fallo de previsualización, se corrigió y se añadió regresión de tres idiomas.
- **EM-014 — VERIFICADO POR CI ESPECIALIZADO:** el cambio de filtros de fecha y el botón Filtrar envían navegación `_top` para actualizar los errores del formulario; el texto de búsqueda conserva la actualización del Turbo Frame. Nueva regresión Capybara de rango invertido y corrección.
- **EM-015 — VERIFICADO POR CI ESPECIALIZADO:** el modelo detecta marcadores `{{...}}` incompletos o mal formados por campo y el renderer los rechaza también si se usa una fuente anterior sin modelo. Nuevas pruebas de modelo, renderización y vista previa 422.
- **EM-016 — VERIFICADO POR CI ESPECIALIZADO:** al publicar invitaciones y recuperaciones se exige un enlace con `href` real, texto accesible, no oculto y conservado tras la misma sanitización usada para enviar el correo. Se mantienen las comprobaciones de declaración y del cuerpo de texto plano. Nuevas pruebas de comentarios HTML, enlaces sin `href` efectivo, ocultos y enlaces correctos.

**Verificación:** [Email Templates CI #42558182620](https://github.com/AliRodri1992/sales_point/actions/runs/42558182620) concluyó `success` en el commit `90a1d35cde8711b3292207f4e48c379307f077fd`: **270 ejemplos RSpec, 0 fallos**, RuboCop especializado e integridad es/en/ko aprobados. Los hallazgos EM-013/014/015/016 están **VERIFICADOS POR PRUEBAS AUTOMATIZADAS**; queda pendiente la validación manual y externa del estándar (EM-003/004/008/009), así como el CI global. **El módulo integral NO está cerrado.** No se han fusionado ramas.

## Reauditoría de estabilidad — AI Dev Suite, 2026-11-08 (EM-017/018)

**SHA de implementación inspeccionado:** `79a3d008b0fbe2f2d6cd6b7cc77706a250991604` en `feature/fixes`. **Método:** análisis de código y contratos por Impeccable, UI UX Pro Max y Ponytail de AI Dev Suite; NO se ejecutaron CLIs originales ni navegador manual en esta reauditoría. Comparación `90a1d35c...79a3d008`: después del CI verde especializado hubo cambios ajenos al código funcional de Plantillas (entre ellos documentación y Sucursales/Usuarios).

### Control de regresiones (IDs existentes)

- **EM-011 a EM-016:** código de las correcciones aún presente. [Email Templates CI #42558182620](https://github.com/AliRodri1992/sales_point/actions/runs/42558182620), SHA `90a1d35cde8711b3292207f4e48c379307f077fd`, terminó **SUCCESS** con **270 ejemplos/0 fallos**, lint especializado y paridad es/en/ko aprobados. Son verificación automatizada previa del código funcional, NO sustituyen la prueba manual de accesibilidad y SMTP de este corte.
- **EM-003, EM-004, EM-008, EM-009:** sin nueva evidencia externa de DNS/proveedor, semántica de reintentos e idempotencia, Gmail/Outlook ni lector de pantalla/zoom 200 %. **Se mantienen abiertos/mitigados conforme al historial**, no se crean IDs duplicados.
- **EM-010 — AMPLIAR, PROBLEMA PROPIO Y CONTRATOS EXTERNOS:** [CI global #42558519267](https://github.com/AliRodri1992/sales_point/actions/runs/42558519267) del SHA `79a3d008` aprobó seguridad, migración/seed e I18n; RuboCop **falló**. La mayoría de ofensas están en módulos externos, pero **hay una ofensa propia**: `app/queries/email_templates_query.rb:72` (`Style/IfUnlessModifier`). No afirmar que todo el fallo global es externo. El [workflow especializado](../../../.github/workflows/email-templates-ci.yml) incluye `spec/queries/email_templates_query_spec.rb` en RSpec, pero **omite el archivo `app/queries/email_templates_query.rb` del lint y de sus filtros de disparo**, y tampoco cubre `app/policies/email_template_policy.rb` ni la ruta canónica `docs/quality/modules/email-templates.md` en los disparadores. **Causa preventiva:** cobertura incompleta del inventario de archivos en el workflow. Registrar la corrección del RuboCop propio y ampliar `paths`/lint para que nuevas modificaciones de consulta/permisos activen CI especializado. El RSpec global estaba todavía en ejecución al inspeccionarlo.

### Nuevos hallazgos propios (no presentes en EM-001..016)

| ID | Prioridad y estado | Evidencia demostrable por código | Adecuación y prueba de regresión requeridas |
|---|---|---|---|
| **EM-017** | **P2 / CONFIRMADO POR CÓDIGO**, prueba de API pendiente | `app/policies/email_template_policy.rb:archive?` concede acceso a plantillas ya archivadas (solo comprueba permiso, tenant y que no sea global crítica). `EmailTemplateLifecycle#archive` siempre actualiza `archived`, crea un nuevo evento `archived` y notifica. La UI oculta el botón tras archivado, pero una segunda petición PATCH al mismo endpoint sigue siendo válida, creando evidencia y notificaciones repetidas. | Hacer explícita la transición válida de archivado/gestionar idempotencia sin crear auditorías duplicadas. Añadir request spec de doble PATCH con estado y contador de auditorías; conservar permisos y protección de plantillas globales críticas. |
| **EM-018** | **P2 / CONFIRMADO POR CÓDIGO**, prueba de navegador/lector pendiente | En `app/javascript/controllers/email_branding_controller.js#logoChanged`, un archivo rechazado muestra `logoErrorTarget` pero no actualiza `aria-invalid` del input ni `aria-describedby` con un ID del error. `app/views/admin/email_branding_settings/edit.html.erb` crea el error con `role="alert"` sin ID; el input solo se vincula con la ayuda y errores Rails. La notificación visual no queda asociada sistemáticamente al control. | Dar ID estable al error de cliente, sincronizar `aria-invalid`/descripción en selección inválida, válida y limpieza; mantener mensajes del modelo debajo del campo sin duplicarlos. Regresión Capybara con JPG/PNG/WebP inválido, selección válida y manejo con teclado/lector de pantalla. |

### Puertas de cierre y límites

**Registros EM-017 y EM-018:** ABIERTOS, **sin cambios funcionales** en esta reauditoría. **EM-010:** ampliado sin duplicar ID; a diferencia de los errores de Sucursales/Inventarios/Compras, la ofensa de `email_templates_query.rb` pertenece a Plantillas. Ejecutar RSpec focalizado y especializado al corregir; exigir CI global verde del SHA de aceptación; contrastar UI real con teclado/zoom y SMTP/cliente real antes del cierre. NO hacer merge ni declarar el módulo completamente cerrado con estos pendientes.

## Adecuaciones EM-010, EM-017 y EM-018 — 2026-11-08

- **EM-017 — VERIFICADO POR CI ESPECIALIZADO:** política niega archivar plantillas archivadas y se comprueba el estado bajo bloqueo de base de datos, sin auditorías ni notificaciones duplicadas al concurrir peticiones. Regresiones de PATCH/DELETE repetidos y política.
- **EM-018 — VERIFICADO POR CI ESPECIALIZADO:** error del logotipo debajo del control con ID estable y texto de campo; JavaScript sincroniza `aria-describedby`/`aria-invalid`, y restituye la semántica anterior cuando se selecciona un archivo válido o se quita. Se preservan mensajes Rails. Nueva prueba Capybara con archivo >2 MB, PNG válido y móvil.
- **EM-010 — VERIFICADO EN ALCANCE PROPIO POR CI ESPECIALIZADO; CI GLOBAL PENDIENTE:** corregida la ofensa `Style/IfUnlessModifier` de `EmailTemplatesQuery`. El workflow especializado observa/linta query y políticas, revisa sus specs e incluye la prueba de branding y la ruta canónica del expediente.

**Evidencia:** [Email Templates CI #42560064167](https://github.com/AliRodri1992/sales_point/actions/runs/42560064167) concluyó **success** en el SHA `cc3772529bbc0f38d4707090a9430d702f0b3331`: **272 ejemplos RSpec, 0 fallos**; RuboCop ampliado e i18n es/en/ko aprobados. Las pruebas Capybara cubren el estado del logotipo inválido/corregido y vista móvil. La protección contra solicitudes concurrentes se implementó con bloqueo y comprobación de estado; la regresión automatizada verifica peticiones secuenciales, no una carrera real. **Límites:** pendiente CI global de aceptación y verificaciones externas de SMTP, SPF/DKIM/DMARC, Gmail/Outlook, lector de pantalla, teclado y zoom 200 %. Los errores internos de otros módulos mantienen propietario externo. No fusionar ni declarar cierre integral sin evidencias.

## Reauditoría integral — AI Dev Suite, 2026-11-08 (EM-019 a EM-021)

**Rama / SHA base analizado:** `feature/fixes` / `d7d232239de28132d758b85ca11cd648e9ce7101`. **Procedimiento:** revisión de código y contratos con las guías de Impeccable (estados/errores/UX), UI UX Pro Max (accesibilidad, mensajes y casos móviles), Ponytail (límites de seguridad, concurrencia y pruebas). No se invocaron las CLI originales ni una instancia de la aplicación en navegador manual. Se inspeccionaron modelo/versiones, políticas, queries e índices, editor y sus errores, remitentes, branding, renderizador, muestras, jobs, mailers y pruebas existentes. Esta reauditoría **no implementa** ajustes funcionales.

### Regresión, cobertura y CI al SHA inspeccionado

- **EM-001/002/005/006/007/011–018:** no se reabren sin evidencia. Comparación GitHub desde `43c9d55795c9e1be714676dab67f7194e0c4431f` hasta `d7d232239de28132d758b85ca11cd648e9ce7101`: **ningún archivo funcional de Plantillas modificado**. [CI especializado #42560381088](https://github.com/AliRodri1992/sales_point/actions/runs/42560381088) **APROBÓ** el SHA de verificación anterior: 272 ejemplos, 0 fallos; RuboCop de Plantillas e i18n es/en/ko aprobados. No atribuir ejecución de pruebas nuevas a esta reauditoría.
- **EM-003/004/008/009:** permanecen abiertos o mitigados: DNS/SPF/DKIM/DMARC, idempotencia efectiva del proveedor, Gmail/Outlook y lector de pantalla/teclado/zoom real. El CI y Capybara no los sustituyen.
- **EM-010 — puerta global:** [CI global #42562001050](https://github.com/AliRodri1992/sales_point/actions/runs/42562001050) en `d7d23223`: seguridad, migraciones/seed básico e I18n aprobaron; RuboCop **FALLÓ (32 ofensas)**, sin archivos propios de Plantillas en la lista, incluyendo errores de sintaxis en `spec/services/inventories/fefo_allocator_spec.rb` y `spec/services/purchases/receive_spec.rb`. El job **RSpec FALLÓ** por `spec/seeds/full_seed_repeatability_spec.rb:87` con `Pundit::NotAuthorizedError` de Roles; la prueba de seed completo NO está aprobada aunque el job básico de migraciones/semillas sí. Estos fallos pertenecen a sus respectivos módulos; solo bloquean aceptación global de Plantillas.
- **EM-010 — cobertura especializada residual:** aunque el workflow actual observa la consulta y políticas principales, **no** observa ni linta `app/policies/email_setting_audit_policy.rb`, ni observa `app/notifications/email_template_notification.rb`, pese a que ejecuta pruebas de autorización/auditoría y notificaciones. Añadir esas rutas explícitas al inventario de disparadores, el fichero de policy al lint y la notificación si corresponde; así los cambios que afecten directamente a Plantillas no pasarán inadvertidos. No convertirlo en un ID nuevo.

### Nuevos hallazgos verificables por lectura de código

| ID | Prioridad / estado | Causa raíz y evidencia | Adecuación precisa y criterio de regresión |
|---|---|---|---|
| **EM-019** | **P1 / RIESGO CONFIRMADO POR CONTRATO; envío real no reproducido** | `EmailTemplateVersion#declared_variables` admite variables de URL sensibles en `subject` y `preheader`. `EmailTemplates::Renderer#render_subject` reemplaza `{{activation_url}}` y `{{recovery_url}}` literalmente y `#inject_preheader` hace lo mismo dentro del texto de previsualización de bandeja. Las validaciones del enlace obligatorio en HTML y texto no prohíben estas apariciones. Una plantilla crítica correctamente publicada puede exponer enlaces con tokens personales en encabezados visibles y logs de asuntos. | Rechazar `activation_url`/`recovery_url` en asunto y preencabezado **desde modelo** y aplicar defensa en renderer para snapshots publicados previos; preservar variables en enlace HTML válido y texto plano. Probar publicación (422) y renderización legacy por es/en/ko; validar que los encabezados no contienen la URL sensible. |
| **EM-020** | **P2 / FALLA DE CONCURRENCIA INFERIDA POR FLUJO; pendiente spec simultánea** | `EmailTemplateVersion#publish!` valida `status == 'draft'` **antes** de bloquear el template; bloquea `email_template`, pero no vuelve a cargar la versión tras tomar el bloqueo. La migración `20261109040000_add_optimistic_lock_to_email_template_versions.rb` implementó `lock_version`. Ante dos solicitudes que ya leyeron el mismo borrador, la segunda puede recibir `ActiveRecord::StaleObjectError`. `Admin::EmailTemplatesController#publish` solo rescata `ActiveRecord::RecordInvalid` y `ArgumentError`, exponiendo error 500 en lugar de conflicto controlado. | Serializar/revalidar la versión y capturar `StaleObjectError` con respuesta localizada y sin publicar dos veces; preservar una sola auditoría/notificación de publicación. Añadir prueba con dos sesiones o transacciones realmente superpuestas, no solo dos PATCH secuenciales. |
| **EM-021** | **P2 / DESAJUSTE CONFIGURACIÓN–PREVIEW; pendiente integración de producción** | `EmailTemplates::Branding.contact_values` proporciona `support@example.org`, `https://example.org/support` y `https://example.org/privacy` como fallback. `SampleData` y los endpoints `preview` los aceptan con `preview: true`; `Renderer#example_host?` rechaza tales direcciones durante el envío productivo. `EmailTemplateVersion#publish!` no comprueba que los valores de branding **referenciados por esa versión** sean entregables. Una plantilla con `{{support_email}}`/`{{support_url}}`/`{{privacy_url}}` puede publicarse y previsualizar correctamente para después fallar asincrónicamente en entrega. Distinto de EM-002 (host de activos) y EM-003 (autenticación DNS del remitente). | Validación de preparación de entrega **solo para variables realmente utilizadas** (sin exigir configuración no referenciada) y aviso por campo/estado antes de habilitar publicación, preservando modelo y localización. Probar modo producción: sin contactos configurados y con fallbacks reales, en vista previa, publicación y job. No suprimir el rechazo seguro del renderer. |

### Dictamen y criterio de cierre

**EM-019/020/021: ABIERTOS para adecuación y nuevas regresiones, NO CORREGIDOS NI PROBADOS EN ESTA REAUDITORÍA.** Las observaciones se sustentan en rutas de código; no hay evidencia de fuga real de tokens, publicación simultánea que haya causado 500 ni correo perdido en producción. **EM-010** sigue pendiente por CI global y cobertura residual; **EM-003/004/008/009** por proveedores y pruebas manuales. No tocar ramas ni módulos externos, ni declarar calidad integral cerrada sin sus verificaciones. La siguiente intervención debe usar estos mismos identificadores y evitar reiniciar el registro.

## Adecuaciones EM-019 a EM-021 y EM-010 — 2026-11-08

- **EM-019 — IMPLEMENTADO / CI PENDIENTE:** tanto modelo como renderer rechazan enlaces de activación/recuperación en `subject` y `preheader`, incluidas versiones publicadas heredadas. Mensajes del modelo por campo, traducciones es/en/ko y regresiones.
- **EM-020 — IMPLEMENTADO / CI PENDIENTE:** la publicación recarga la versión después de tomar el bloqueo del template, detecta versiones que dejaron de ser borrador, genera `StaleObjectError` y responde desde controlador con aviso localizado, sin segunda auditoría. Pruebas de snapshots desactualizados y solicitud duplicada (no prueba de carrera real).
- **EM-021 — IMPLEMENTADO / CI PENDIENTE:** el modelo valida en producción solo los contactos `support_email`, `support_url`, `privacy_url` realmente usados antes de publicar, con error en `allowed_variables`; el dispatcher vuelve a verificar antes de encolar un snapshot legado. Conserva `Renderer` seguro y las previsualizaciones con muestras. Regresiones de fallos y configuración válida.
- **EM-010 — COBERTURA ESPECIALIZADA IMPLEMENTADA / CI PENDIENTE:** `EmailSettingAuditPolicy` y `EmailTemplateNotification` ya están en disparadores y RuboCop especializado; las dependencias del CI global permanecen en sus módulos.

**Limitaciones de cierre:** no se ha verificado un proveedor SMTP real, SPF/DKIM/DMARC, idempotencia efectiva del proveedor ni Gmail/Outlook y lector de pantalla/zoom 200 %; EM-003/004/008/009 mantienen su estado externo hasta contar con el entorno. Los errores de CI global fuera de Plantillas conservan propietario externo. Sin merge.

## Reauditoría de estabilidad — AI Dev Suite, 2026-11-09 (post EM-019 a EM-021)

**Código inspeccionado:** `d414ec7d6380dd75675836c05b501391c010365f`, rama `feature/fixes`. Al terminar, el árbol avanzó hasta `d1361e206189b2be4b0999e3f55fa3c2aea6dc61` por ajustes del registro de Usuarios; comparación del diff sin archivos funcionales de Plantillas. **Método:** lectura de modelos, controlador, políticas, renderer, publicación, dispatcher, delivery readiness, remitentes y branding; validaciones, estados, i18n, specs y workflow. Guías procedimentales AI Dev Suite (Ponytail, Impeccable, UI UX Pro Max); sin invocar sus CLI externas, un navegador de producción ni un proveedor SMTP.

### Verificación de las correcciones anteriores

- **EM-019, EM-020, EM-021 y EM-010 (cobertura especializada) — VERIFICADOS POR CI AUTOMATIZADO:** [Email Templates CI #42566550249](https://github.com/AliRodri1992/sales_point/actions/runs/42566550249) terminó en **success** para `6d1fd6f05f318298990622cf41fc8b98723aae36`, con **282 ejemplos/0 fallos**, RuboCop e integridad/paridad es/en/ko aprobados. Comparación con SHA inspeccionado: migración, schema, backup de schema y registro de Roles únicamente.
- **Repetición sobre el SHA inspeccionado:** [Email Templates CI #42609077149](https://github.com/AliRodri1992/sales_point/actions/runs/42609077149) igualmente **success**, **282 ejemplos/0 fallos**, lint e i18n correctos. Se conserva evidencia sobre el corte más reciente.
- **EM-003, EM-004, EM-008 y EM-009:** sin pruebas nuevas de DNS/SPF/DKIM/DMARC, idempotencia de proveedor, recepción Gmail/Outlook, teclado/lector de pantalla/zoom 200 %; NO cerrar.
- **EM-010 (CI global):** [CI #42609077039](https://github.com/AliRodri1992/sales_point/actions/runs/42609077039) en `d414ec7d` con seguridad, migración/semillas e i18n correctos; RuboCop **failure** por **32 ofensas**, fuera de archivos del módulo de Plantillas (principalmente inventarios, compras, branch-guard y utilidades). RSpec global **cancelled**; no se considera aprobado. La cobertura específica de Plantillas sí pasó.

### Hallazgo propio: ampliar EM-016, no crear ID nuevo

**EM-016 (subcaso de accesibilidad de enlaces críticos) — P2 / CONFIANZA ALTA POR CÓDIGO, REPRODUCCIÓN AUTOMATIZADA PENDIENTE.** `EmailTemplateVersion#visible_security_link?` toma `link.text.strip.present?` o imágenes con `alt`, y comprueba ocultación solo en el enlace y ancestros; **no** comprueba nodos hijos que contienen todo el texto/imagen. Ejemplo:

```html
<a href="{{recovery_url}}"><span style="display:none">Recuperar contraseña</span></a>
```

`actionable_security_link?` repite el mismo chequeo tras `Renderer.sanitize_html`, que permite `span` y `style`; Loofah admite CSS `display` (ver [documentación de CSS sanitization](https://thedocumentation.org/loofah/advanced/uri_and_css/)). Por ello puede validar una plantilla de recuperación con enlace pero sin etiqueta visible, aunque las regresiones anteriores prueban solo `<a style="display:none">...` y ancestros ocultos. Las comprobaciones actuales **no prueban este descendiente oculto**.

**Adecuación y prueba de aceptación:** comprobar, en el HTML saneado, que exista un descendiente de texto o imagen con `alt` verdaderamente visible bajo el enlace, considerando la cadena de ancestros **hasta el enlace**; negar casos donde todos estén ocultos con `display:none`, `visibility:hidden` o `font-size:0`, sin rechazar enlaces con al menos una etiqueta visible real. Añadir casos `span`, `img`, mezclas ocultas/visibles y los tres locales, ejecutando model specs, request de publicación, renderer y CI especializado. No declarar EM-016 cerrado para este subcaso antes de la prueba.

**EM-020 — cobertura manual/especializada adicional:** las regresiones actuales protegen solicitud duplicada y snapshot obsoleto, pero no simulan dos transacciones de publicación que se solapen realmente; esto sigue como **verificación de concurrencia pendiente**, no un error funcional nuevo.

### Dictamen

**Auditoría de código y CI especializado APROBADOS, con EM-016 ampliado y pendiente de prueba/corrección específica; NO cierre integral del módulo** debido a EM-003/004/008/009, RSpec/RuboCop globales y pruebas manuales/externas. No hubo cambios funcionales ni merge en esta reauditoría. Las secciones históricas reflejan el estado de su fecha, no sustituyen esta actualización.

## Adecuaciones de reauditoría — 2026-11-09: EM-016 y EM-020

- **EM-016 — VERIFICADO POR CI ESPECIALIZADO:** `EmailTemplates::SecurityLinkVisibility` valida contenido visible descendiente (texto o ALT de imagen), excluyendo nodos y ancestros ocultos por `hidden`, `aria-hidden`, `display:none`, `visibility:hidden/collapse`, `opacity:0` y `font-size:0`. Se conserva la revisión antes y después del saneamiento de HTML en `actionable_security_link?`. Regresiones a nivel de servicio y modelo para los tres locales, incluyendo contenido mixto visible/oculto.
- **EM-020 — SUPERPOSICIÓN REAL VERIFICADA POR CI ESPECIALIZADO:** RSpec usa dos hilos con conexiones independientes. Una transacción retiene el bloqueo real de PostgreSQL en el template; el segundo hilo inicia `publish!` mientras el bloqueo sigue tomado, luego la primera transacción completa. Se exige conflicto controlado en el segundo hilo, una versión publicada y una única auditoría.
- **EM-003/004/008/009:** continúan sin verificación de proveedor SMTP, DNS/SPF/DKIM/DMARC, Gmail/Outlook ni lector de pantalla/teclado/zoom 200%; los resultados de CI no sustituyen estas comprobaciones.
- **EM-010:** cierre integral aún dependiente del CI global, manteniendo propietario de errores ajenos en sus propios módulos. Sin mezcla de código de Sucursales/Inventarios/Compras ni merge de ramas.

### Evidencia de aceptación de EM-016 y EM-020 (corte 2026-11-09)

- **[Email Templates CI #42613930449](https://github.com/AliRodri1992/sales_point/actions/runs/42613930449) — SUCCESS**, SHA `b35bc264e6023c3ed6ac952b0ec2497e65c4cd67`: **287 ejemplos, 0 fallos**, RuboCop especializado e integridad/paridad es/en/ko correctos.
- **EM-016 cerrado para el subcaso detectado:** las pruebas de unidad y modelo verifican que las URL de recuperación o activación no sean aceptadas si los únicos textos o imágenes `alt` están ocultos en descendientes. Se rechazaron también imágenes de ancho/alto cero; el enlace con una etiqueta visible legítima se conserva. No se modificaron snapshots publicados.
- **EM-020 cerrado para la prueba de concurrencia PostgreSQL:** el escenario usa conexiones separadas, transacciones realmente superpuestas y espera de bloqueo observable; termina con una única versión publicada y un solo registro de auditoría. Se configuró `concurrent_db` para visibilidad real de registros entre conexiones, con límites de espera.
- **Contrato de accesos sin tenant:** se ajustaron las regresiones de Plantillas al control vigente de identidad: cuentas con membresías retiradas no recuperan acceso; los usuarios sin contexto autorizado no editan plantillas globales. La creación de una plantilla global sigue disponible para un superadministrador con membresía activa. No se deshabilitaron controles compartidos de autenticación.
- **EM-010:** el workflow especializado observa tanto `spec/models/email_templates/**` como servicios, políticas y notificaciones del módulo. **El CI global continúa independiente** y requiere aprobación de errores propios de otros módulos por sus respectivos responsables.
- **No verificados externamente:** EM-003 (SPF/DKIM/DMARC en dominio real), EM-004 (idempotencia garantizada por el proveedor de salida), EM-008 (recepción visual en Gmail/Outlook) y EM-009 (teclado/lector de pantalla/zoom 200 % manual). Sin un entorno o proveedor accesible, no es correcto marcar estos criterios como aprobados. Se mantienen pendientes de evidencia de aceptación.

**Dictamen específico:** EM-016 y EM-020 superan código, regresiones y CI especializado. **Módulo completo no cerrado** mientras falten las validaciones externas y el CI global de aceptación. Sin merge.
