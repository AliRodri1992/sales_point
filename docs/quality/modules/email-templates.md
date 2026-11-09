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
