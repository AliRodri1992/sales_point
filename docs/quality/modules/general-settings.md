# Registro de calidad — General (`/admin/general_settings`)

**Estado actual:** REAUDITADO 2026-11-09; ANTERIORES ADECUACIONES CONSERVADAS; GENERAL CI VERDE (42 ejemplos, 0 fallos); NUEVOS HALLAZGOS 015 (P2) Y 016 (P3), PENDIENTES DE CORRECCIÓN; CI GLOBAL CON FALLOS EXTERNOS Y REVISIÓN VISUAL INDEPENDIENTE PENDIENTES; NO CERRADO.  
**Fecha:** 2026-11-08 (America/Mexico_City). **Rama:** `feature/fixes`.  
**SHA base de inspección:** `8974fee011f9422066985a0ab088ed2d771e1c8a`. **SHA revisado posteriormente:** `719ae720c3464bbab3478ef7cd91399b5c911b53` (comparación sin cambios en archivos de General).  
**SHA de aceptación:** PENDIENTE. **Responsable propuesto:** equipo Delta POS. **Revisor independiente:** PENDIENTE.  
**Método AI Dev Suite:** Impeccable (UI, mensajes, accesibilidad), UI UX Pro Max (consistencia, estados, i18n) y Ponytail (lógica, autorización, pruebas y fronteras).

> Auditoría de código publicada mediante conector GitHub y lectura no interactiva de la pestaña local `http://localhost:3000/admin/general_settings`. **No** equivale a pruebas funcionales en navegador, capturas, ejecución de RSpec o CI. Los defectos se clasifican según la evidencia, nunca por suposiciones.

## 1. Alcance y fronteras

**Propio:** `GET /admin/general_settings` (`show`) y `PATCH /admin/general_settings` (`update`). Formulario y preview de la preferencia `default_table_page_size`; controlador `Admin::GeneralSettingsController`; validación de `OrganizationSetting`; traducciones del formulario es/en/ko; render del campo, errores, permisos y request specs.

**Contrato de integración, no auditoría del módulo vecino:** `Admin::TablePagePreferencesController`, `TablePageSizing`, `TablePagePreference` (precedencia entre valor global, ajuste por usuario y parámetro en URL); selección de organización mediante `/admin/organizations/:id/select` (que el cambio de contexto seleccione las preferencias correctas); componente compartido `delta-select` y breadcrumbs. Los detalles internos de estos componentes corresponden a sus dueños; únicamente se registra aquí el comportamiento visible en General.

**Fuera de alcance:** CRUD de Sucursales, Onboarding, Terminales, Compras, Inventarios, Plantillas de correo, idioma y perfiles, salvo el contrato indispensable para mostrar el ajuste.

| Ruta/acción | Código | Control de acceso | Evidencia |
|---|---|---|---|
| GET General | `app/controllers/admin/general_settings_controller.rb:9-11` | `authenticate_user!`, `require_admin!`, `current_organization` | Código + pestaña local leída |
| PATCH General | `app/controllers/admin/general_settings_controller.rb:13-21,26-37` | Filtro de parámetros `params.expect`; modelo validado | Código; request specs existentes **NO ejecutados** |
| Prioridad y persistencia de página | `app/controllers/concerns/table_page_sizing.rb:7-24` | Preferencia por usuario/organización | Contrato leído, no probado |
| Selección de organización | `app/controllers/admin/organization_selections_controller.rb` | Organización en `available_organizations` | Contrato leído, no probado aquí |

## 2. Hallazgos con ID estable

### GENERAL_SETTINGS-001 — P2 · PROPIO · confirmado por código y lectura de pantalla · ABIERTO

**Breadcrumb no localizado.** La pestaña local en español muestra `Inicio / General settings`. `app/helpers/breadcrumbs_helper.rb:16-19` cae en `controller_name.humanize` y las tres traducciones `config/locales/breadcrumbs_controllers.{es,en,ko}.yml` omiten `general_settings`. **Esperado:** `Configuración general`, `General settings` y equivalente coreano según el locale. **Causa:** falta la clave específica. **Arreglo:** añadir las tres claves y test del breadcrumb en los tres idiomas. **Regresión requerida:** request/helper spec, locale es/en/ko. **Verificación:** NO EJECUTADA.

### GENERAL_SETTINGS-002 — P2 · PROPIO · confirmado por código · ABIERTO

**Campo requerido sin indicador ni vínculo accesible con los errores.** `app/views/admin/general_settings/show.html.erb:36-43` utiliza `f.label`, `f.select` y `error_message_for` pero no `required_field_label`, `aria-invalid` ni `validation_describedby`. El modelo obliga a elegir una de las opciones `5,10,15,25,50` (`app/models/organization_setting.rb:28-30`). El helper `app/helpers/form_validation_helper.rb` ya ofrece estas utilidades. **Esperado:** asterisco rojo, error individual `nombreCampo mensajeValidación` bajo el campo, borde de error y asociación `aria-describedby` tanto en select nativo como en disparador personalizado; sin `required` HTML5 ni resumen redundante. **Arreglo:** reutilizar los helpers y mantener sincronizado `delta-select`. **Regresión requerida:** HTML de 422, accesibilidad y foco en el dropdown. **Verificación:** NO EJECUTADA.

### GENERAL_SETTINGS-003 — P2 · PROPIO · confirmado como caso condicional de código · ABIERTO

**Error de modelo ajeno al único campo puede impedir guardar sin explicación.** `OrganizationSetting` valida también zona horaria, método de pago y moneda activa en `update` (`app/models/organization_setting.rb:7,24-38,53-56`); el formulario de General solo presenta errores de `default_table_page_size` (`show.html.erb:43`). **Reproducción requerida:** en una organización de prueba con moneda base inactiva o dato heredado inválido, enviar PATCH con tamaño válido. **Esperado:** aviso específico y acción de recuperación visible; no ocultar la causa ni mostrar una validación incorrecta bajo el único selector. **Arreglo:** definir contrato de validación para esta acción y una salida contextual para errores de otros campos sin lista duplicada. **Regresión requerida:** PATCH 422 con atributo no presente en la pantalla. **Verificación:** NO EJECUTADA.

### GENERAL_SETTINGS-004 — P2 · PROPIO · confirmado por código · ABIERTO

**Vista previa no representa la selección actual.** `show.html.erb:76` dibuja siempre tres filas; en `:88` el texto usa el valor almacenado en `@settings`. No hay enlace JS entre el selector y la tarjeta. Cambiar de 10 a 25 antes de guardar no actualiza la vista previa y, aun después, solo aparecen tres filas ilustrativas. **Esperado:** un ejemplo marcado inequívocamente como ilustrativo o una vista previa reactiva y coherente. **Arreglo:** aclarar el texto/representación o sincronizar el valor elegido sin simular que la tabla tiene exactamente ese número de filas. **Regresión requerida:** prueba browser al cambiar opción sin guardar y tras persistir. **Verificación:** NO EJECUTADA.

### GENERAL_SETTINGS-005 — P2 · PROPIO · confirmado por código, decisión de negocio pendiente · ABIERTO

**Sin recuperación cuando no existe ajuste activo.** `app/controllers/admin/general_settings_controller.rb:30-32` devuelve 404 si falta el registro activo, tanto si fue archivado como si aún no se creó. El spec `spec/requests/admin/general_settings_spec.rb:41-49` solo exige 404 tras archivo, no documenta recuperación de organización incompleta o heredada. **Esperado por definir:** mantener 404 en archivo deliberado, pero ofrecer diagnóstico/creación segura cuando falta el registro por inicialización incompleta, sin reactivar un dato archivado por accidente. **Regresión requerida:** organización sin `organization_settings`, archivada e inicializada. **Verificación:** NO EJECUTADA.

### GENERAL_SETTINGS-006 — P2 · INTEGRACIÓN con preferencias de tablas · confirmado por código · ABIERTO

**El soft delete de la preferencia personal no se respeta al leer ni al guardar.** `TablePagePreference` contempla `deleted_at` en la unicidad activa (`app/models/table_page_preference.rb:15-18`), pero `TablePageSizing` lee con `current_user.table_page_preferences.find_by(...)` sin filtrar `deleted_at` (`app/controllers/concerns/table_page_sizing.rb:12-16`). Igualmente `Admin::TablePagePreferencesController` usa `find_or_initialize_by` sin filtro activo (`:17-20`). Una preferencia archivada puede prevalecer sobre el valor general y/o reusarse en una operación nueva. **Esperado:** la precedencia excluye registros archivados y no se reusa uno eliminado salvo restauración explícita. **Propietario:** preferencias de tablas (contrato compartido); no ampliar esta auditoría a listados individuales. **Regresión requerida:** preferencia archivada y preferencia activa coexistentes; GET de listado y PATCH de preferencia. **Verificación:** NO EJECUTADA.

### GENERAL_SETTINGS-007 — P2 · PROPIO · confirmado en controlador/modelo inspeccionados; alcance de auditoría transversal pendiente · ABIERTO

**Cambio administrativo sin evento de auditoría explícito en esta acción.** El PATCH (`general_settings_controller.rb:17-20`) actualiza y redirige con SweetAlert, pero no registra actor, organización, antes/después o motivo. No se observó instrumentación específica en `OrganizationSetting`. **Esperado por definir:** trazabilidad de cambios de configuración organizacional cuando el requisito de auditoría administrativa lo exija. **Arreglo:** comprobar primero si existe bitácora transversal; si no, registrar un evento acotado y probar que no filtra datos sensibles. **Regresión requerida:** cambio exitoso, inválido y sin permiso; verificar evento solo en éxito. **Verificación:** NO EJECUTADA. **Nota:** no se afirma ausencia absoluta de logging global.

### GENERAL_SETTINGS-008 — P1 condicional · SEGURIDAD/DISEÑO DE PERMISOS · HIPÓTESIS por verificar · ABIERTO

**Semántica de administrador entre varias organizaciones.** `GeneralSettingsController#require_admin!` usa `current_user.admin? && current_organization` (`:26-28`); `User#admin?` comprueba un rol de sistema global sin `organization_id` (`app/models/user.rb:78-82`). `ApplicationController#available_organizations` solo permite membresías activas (`:20-32`), lo que **sí reduce** la exposición. **Pregunta de negocio:** ¿un rol administrador concede administración sobre *todas* las organizaciones a las que pertenece o solo sobre aquella donde se otorgó? Solo si la respuesta es lo segundo existiría una elevación indebida. **Regresión requerida:** usuario con membresías activas en A/B y rol administrativo; probar GET/PATCH en ambas según política oficial. **Verificación:** NO EJECUTADA; **no se confirma una vulnerabilidad** sin esa regla.

### GENERAL_SETTINGS-009 — P2 · PROPIO · brecha de cobertura confirmada · ABIERTO

**Pruebas insuficientes para cerrar la pantalla.** `spec/requests/admin/general_settings_spec.rb` cubre lectura, éxito, rechazo de tamaño inválido, archivo y rol no administrador, pero no verifica presentación de errores ARIA/422, traducción de breadcrumb es/en/ko, cambio de organización A/B, estado sin registro, error de validación ajeno al campo ni escenarios browser (320/390/768/1440 px, zoom 200 %, teclado y foco). **Esperado:** tests focalizados negativos y browser de los casos anteriores sin duplicar suites globales. **Regresión requerida:** nuevos casos sobre este mismo módulo y contratos. **Verificación:** NO EJECUTADA.

### GENERAL_SETTINGS-010 — P3 · PROPIO · hipótesis de concurrencia · ABIERTO

**Guardar simultáneamente desde dos sesiones aplica última escritura.** El PATCH usa `@settings.update` (`general_settings_controller.rb:17`) y no hay control explícito `lock_version` ni detección de conflicto en los archivos inspeccionados. Al tratarse de un único ajuste, puede ser una decisión aceptable, no necesariamente un error. **Esperado por definir:** confirmar política last-write-wins o advertir conflicto. **Regresión requerida:** dos actualizaciones concurrentes si se requiere detectar colisión. **Verificación:** NO EJECUTADA.

## 3. Pruebas, escenarios positivos y límites

**Ya presentes en código, sin ejecución local confirmada:** request specs para GET, PATCH válido, PATCH con valor inválido, archivo y permiso administrativo; restricción a parámetros permitidos; aislamiento por asociación a `current_organization`; índice único de ajuste activo por organización; checks SQL para tamaños válidos; traducciones de pantalla `es/en/ko`; selector personalizado con opción nativa para envío y control por teclado según código. Estos son **controles observados**, no pruebas pasadas.

**Pendientes:** validación real del campo en 422; prueba multi-tenant A/B; errores 401/403/404/422; traducciones efectivas del breadcrumb; lectura del tamaño elegido en un listado; inactividad/archivo; recuperación tras red/validación; foco, teclado, lector, contraste, ancho 320/390/768/1440, zoom 200 % y movimiento reducido.

| Fecha | SHA | Comprobación | Estado real | Evidencia/limitación |
|---|---|---|---|---|
| 2026-11-08 | `8974fee` a `719ae72` | Inspección GitHub de rutas, controlador, modelo, vista, helpers, JS y specs | REALIZADA, solo estática | Conector GitHub, archivos citados arriba |
| 2026-11-08, ~21:42 CST | código local no cotejado con Git | Lectura de pestaña local `/admin/general_settings` | REALIZADA, solo DOM/texto | Se observó formulario, select y breadcrumb; sin clics, capturas ni resize |
| 2026-11-08 | `8974fee` | GitHub Actions CI | EN PROGRESO al consultar | https://github.com/AliRodri1992/sales_point/actions/runs/42557591638 |
| 2026-11-08 | `956cb93` | GitHub Actions CI | PENDIENTE al consultar | https://github.com/AliRodri1992/sales_point/actions/runs/42557981426 |
| 2026-11-08 | — | RSpec focalizado/completo; RuboCop; Brakeman; auditoría I18n; migraciones limpias | **NO EJECUTADOS** en esta auditoría | Sin terminal/ejecutor del repositorio en el conector de lectura |
| 2026-11-08 | — | Pruebas browser interactivas y accesibilidad | **NO EJECUTADAS** | Herramienta de lectura de pestañas solamente |

## 4. Plan de adecuación y aceptación

**Prioridad de trabajo:** (1) decidir y probar `GENERAL_SETTINGS-008` antes de certificar permisos; (2) corregir `001,002,003` por visibilidad/error; (3) corregir el contrato de soft delete `006` con su propietario; (4) resolver `004,005,007` según producto y auditoría; (5) cubrir `009` y decidir `010`. Mantener el diff del módulo acotado; no usar este expediente para auditar por dentro Sucursales, Onboarding o Compras.

**Puerta de cierre:** primero implementar y añadir tests; luego ejecutar RSpec, RuboCop, Brakeman, I18n y casos browser pertinentes; esperar CI completo verde sobre **el SHA final de aceptación**; revisar independientemente los IDs originales y sus regresiones. Un commit documental no implica corrección.

- **Estado final de esta revisión:** AUDITADO, NO VERIFICADO, NO CERRADO.
- **P0 confirmados:** 0 en el código inspeccionado; no equivale a inexistencia.
- **P1:** 1 hipótesis de permiso condicionada a la política multiorganización (`008`).
- **P2:** 8 hallazgos/casos abiertos (`001`–`007`, `009`), algunos requieren confirmación funcional o decisión de producto.
- **P3:** 1 hipótesis (`010`).
- **Responsable de resolver y revisión independiente:** PENDIENTE.
- **Criterio de mantenimiento:** conservar estos IDs en toda reauditoría; agregar evidencias y cambiar estados individualmente, sin reiniciar el conteo.

Marco: [estándar modular](../module-quality-standard.md) · [plantilla](../module-audit-template.md).

## 5. Adecuaciones propuestas para el commit de implementación (2026-11-08)

Este seguimiento conserva los IDs de la auditoría. La presencia de cambios en Git no equivale a verificación ni cierre: cada ID queda **implementado, pendiente de prueba** hasta CI y revisión independiente.

| ID | Estado | Adecuación |
|---|---|---|
| GENERAL_SETTINGS-001 | Implementado por verificar | Breadcrumb traducido en es/en/ko |
| GENERAL_SETTINGS-002 | Implementado por verificar | Asterisco rojo, validación del modelo por campo y vínculos ARIA en el dropdown |
| GENERAL_SETTINGS-003 | Implementado por verificar | Contexto de validación del campo editable sin revalidar opciones de Onboarding |
| GENERAL_SETTINGS-004 | Implementado por verificar | Stimulus actualiza el resumen de vista previa y aclara que solo hay tres filas ilustrativas |
| GENERAL_SETTINGS-005 | Implementado por verificar | Ausencia de configuración inicial redirige a Onboarding; archivo intencional conserva 404 |
| GENERAL_SETTINGS-006 | Implementado por verificar | Preferencias archivadas excluidas al leer y guardar, sin revivir registros retirados |
| GENERAL_SETTINGS-007 | Implementado por verificar | Historial inmutable con organización, autor, valor anterior y nuevo |
| GENERAL_SETTINGS-008 | Política existente por verificar | El rol administrativo del sistema es global, las organizaciones accesibles exigen membresía activa; regresión multi-tenant |
| GENERAL_SETTINGS-009 | Implementado por verificar | Request specs, modelo, traducción, navegador móvil y escritorio |
| GENERAL_SETTINGS-010 | Implementado por verificar | Conflicto 409 con mensaje en el campo cuando cambió el valor desde otro formulario |

**Pruebas focalizadas a ejecutar:** `bundle exec rspec spec/requests/admin/general_settings_spec.rb spec/requests/admin/table_page_preferences_spec.rb spec/models/organization_setting_spec.rb spec/models/general_setting_audit_event_spec.rb spec/features/general_settings_browser_spec.rb`.

**Cierre bloqueado** hasta ejecutar RSpec completo, RuboCop, seguridad, I18n, migraciones limpias y verificación browser y obtener CI verde del SHA definitivo. No se fusionó ninguna rama.

## 6. Evidencia focalizada de implementación verificada — 2026-11-08

**SHA verificado:** `9e438205e94dca7e44afd021b3cb32d8bde886d7`.  
**Workflow completo:** https://github.com/AliRodri1992/sales_point/actions/runs/42560618778

| Puerta | Resultado real | Evidencia |
|---|---|---|
| General module RuboCop | **PASÓ** | Job de lint focalizado del workflow anterior |
| General translations and YAML integrity | **PASÓ** | Auditoría estricta de claves, sintaxis y paridad es/en/ko |
| General model request and browser regressions | **PASÓ: 35 ejemplos, 0 fallos** | RSpec focalizado con Chrome en Actions, mismo SHA |
| Migraciones de test | **PASÓ** | Paso `bin/rails db:create db:migrate` del job de regresiones |
| Global CI (toda la plataforma) | **PENDIENTE** | https://github.com/AliRodri1992/sales_point/actions/runs/42560618784 |
| Revisión independiente del expediente | **PENDIENTE** | Aun sin aprobación de revisor |

**Correcciones de regresión:** `5e691892` añadió migración de recuperación para bases creadas a partir de un `schema.rb` más reciente que la migración del audit; `9e438205` añadió `deleted_at` (obligatorio por `ApplicationRecord.acts_as_paranoid`) a migraciones iniciales y de reparación, y corrigió los escenarios de test de organizaciones sin registro.

**Decisiones conscientes:** El rol administrativo del sistema sigue siendo global; la organización activa solo se selecciona entre membresías accesibles. No se trasladó una remodelación de roles/organizaciones al alcance de General.

**Dictamen actualizado:** implementación **verificada focalmente en GitHub Actions** sobre `9e438205`; el módulo permanece **NO CERRADO** de acuerdo con el estándar modular hasta disponer de CI global verde para el SHA de aceptación, verificación final y revisión independiente. Mantener todos los IDs originales sin reiniciar la auditoría.

## 7. Reauditoría independiente — calidad visual premium y regresiones (2026-11-08)

**Referencia estática del código:** `e8c4627bbb315f7d9e567f082703ed736226cfb9`, rama `feature/fixes`. **Código no cambiado por esta reauditoría.** AI Dev Suite: Impeccable + UI UX Pro Max + Ponytail (procedimientos de inspección aplicados al código). No se ejecutó CLI original de terceros. La pestaña local de la app no estuvo disponible en esta revisión, por lo que no se produjeron capturas ni una nueva prueba visual manual.

**Evidencia heredada y verificada:** General Settings CI https://github.com/AliRodri1992/sales_point/actions/runs/42560618778, SHA `9e438205e94dca7e44afd021b3cb32d8bde886d7`: RSpec focalizado y navegador Chrome **35 ejemplos / 0 fallos**, RuboCop PASS, YAML/I18n PASS y preparación de BD con migración PASS. Entre ese SHA y el de inspección, la comparación de GitHub mostró 8 commits y **ningún cambio en controlador/vista/modelos/JS/migraciones de General o componentes compartidos inspeccionados**; el registro de calidad sí cambió. Esto **no** sustituye la puerta de CI global sobre el SHA final ni pruebas manuales de accesibilidad.

### 7.1 Revisión de IDs originales (no reiniciar conteo)

| ID | Estado de reauditoría | Fundamento |
|---|---|---|
| GENERAL_SETTINGS-001 | IMPLEMENTADO; evidencia focalizada PASS | Claves es/en/ko presentes en `breadcrumbs_controllers.*.yml` y prueba de traducción |
| GENERAL_SETTINGS-002 | IMPLEMENTADO; accesibilidad completa PENDIENTE | Asterisco, ARIA, error bajo campo y CSS compartido `[data-controller~="delta-select"] > button[aria-invalid="true"]` que **sí** aplica borde rojo visible; no marcar como fallo nuevamente |
| GENERAL_SETTINGS-003 | IMPLEMENTADO; regresión PASS | Contexto `:general_settings` valida el tamaño sin bloquear por campos de Onboarding |
| GENERAL_SETTINGS-004 | IMPLEMENTADO; regresión browser PASS | Resumen de vista previa reactivo; 3 filas identificadas como ilustrativas |
| GENERAL_SETTINGS-005 | **REABIERTO, P2** | Código del redirect y `OnboardingController#show` revela huecos de recuperación para organización completada y posible desajuste de organización; detalle abajo |
| GENERAL_SETTINGS-006 | IMPLEMENTADO; regresiones PASS | Solo `active_records` tanto en lectura como al crear preferencia por tabla |
| GENERAL_SETTINGS-007 | IMPLEMENTADO; regresiones PASS, contrato de esquema INCOMPLETO | Cambios con actor, organización y antes/después; esquema versionado pendiente (011) |
| GENERAL_SETTINGS-008 | SEMÁNTICA ACTUAL CONOCIDA; REVISIÓN DE POLÍTICA PENDIENTE | `User#admin?` refleja rol administrativo de sistema; `current_organization` exige membresía accesible. No declarar vulnerabilidad sin una política contraria |
| GENERAL_SETTINGS-009 | COBERTURA FOCAL PASS; verificación UI ampliada PENDIENTE | 35 tests, pero no se ensayaron zoom 200 %, navegación por teclado/lector ni todos los estados con capturas en esta revisión |
| GENERAL_SETTINGS-010 | **PARCIAL, P2** | Hay verificación de valor esperado con `with_lock` y test 409; el parámetro `expected_default_table_page_size` es opcional, y el chequeo de valor no detecta cambios A→B→A. No se confirma corrupción, pero la protección no es universal |

### 7.2 Hallazgos actuales y recomendaciones nuevas

**GENERAL_SETTINGS-005 · P2 · PROPIO + CONTRATO de Onboarding · confirmado por inspección de código.** Si una organización *ya completó* el onboarding pero no tiene `OrganizationSetting` activo ni archivado, General la redirige a `admin_onboarding_path`; `Admin::OnboardingController#show` responde al estado `onboarding_completed?` enviándola de nuevo al dashboard. El administrador no obtiene vía General una recuperación. Además, Onboarding selecciona la primera membresía accesible en su propio `set_organization`, no necesariamente la organización seleccionada en General. **Reproducción pendiente:** dos organizaciones accesibles con seleccionada B, y B sin configuración. **Esperado:** recuperación de B acotada y autorizada, sin afectar A; estado archivado intencional separado. **Propietarios:** General (flujo de entrada); Onboarding (solo contrato de organización). **Pruebas:** organización completada sin ajustes, selección A/B, permisos y archivo.

**GENERAL_SETTINGS-010 · P2 · PROPIO · caso límite confirmado por código, efecto por reproducir.** Con PATCH sin `expected_default_table_page_size` el control de conflicto se omite (`stale_preference?` devuelve falso), aunque el controlador lo exige desde el formulario. Un ciclo 10→25→10 tampoco se distingue de la versión previa de 10. **Esperado:** política explícita de compatibilidad y un token de versión verificable en servidor cuando se exija protección contra sobrescritura; test sin token y de cambio concurrente real, no solo un test manual de 409. **No afirmar una explotación de seguridad.**

**GENERAL_SETTINGS-011 · P2 · PROPIO · confirmado por inspección de artefacto.** `db/schema.rb` en el SHA de revisión define versión `2026_11_10_010100` y no tiene `create_table "general_setting_audit_events"`. La tabla aparece en las migraciones `20261109071000` y de reparación `20261110020000`, y `deleted_at` se completa en `20261110030000`; migrar durante la preparación focalizada **sí pasó**, pero **la carga del snapshot sola no contiene la tabla**. **Esperado:** regenerar y versionar un schema coherente con las migraciones, ejecutar tanto `db:schema:load` como `db:migrate` en bases efímeras; sin regenerar manualmente columnas, índices ni checks. **Prueba:** crear base vacía por ambos caminos, comprobar tabla, índices, FK, checks, columna `deleted_at` y escritura del audit.

**GENERAL_SETTINGS-012 · P2 · PROPIO · confirmado por CSS y cálculo de contraste.** Los encabezados pequeños `Registro` y `Estado` del ejemplo en `show.html.erb` usan `text-slate-400` (#94a3b8) sobre blanco (#fff): razón de contraste aproximada **2.56:1**; no alcanza 4.5:1 de WCAG AA para texto pequeño. **Esperado:** usar un token de texto más oscuro (p.ej. `text-slate-600`, ~4.76:1 en blanco), comprobar contraste renderizado en ambos temas y no alterar otros componentes ajenos. **Prueba:** axe/contrast checker y captura de la pantalla.

**GENERAL_SETTINGS-013 · P3 · PROPIO · confirmado por controlador y vista.** El botón `Guardar preferencia` sigue activo sin cambios; un PATCH igual al valor anterior vuelve a redirigir con `saved` («actualizada correctamente») aunque **no** genera auditoría. No hay estado visible «Sin cambios»/«Cambios pendientes». **Esperado:** deshabilitar el CTA hasta modificar el valor (sin bloquear teclado/fallback) o comunicar guardado sin novedades de forma precisa; detectar cambio respecto al valor inicial y restaurar estado tras respuesta. **Prueba:** load sin cambios, elegir opción, volver al valor inicial, guardar, error y Turbo.

**GENERAL_SETTINGS-014 · P3 · RECOMENDACIÓN VISUAL, NO BUG CONFIRMADO.** La pantalla ya tiene una jerarquía coherente, dos superficies responsivas, paleta esmeralda/gris y un componente de selección consistente. Para elevarla a estética empresarial **moderna, elegante y sobria**, conviene reducir el exceso de fondos esmeralda repetidos, reservar el color acento para control principal/confirmación, alinear título/ayuda con la acción principal, dar al preview una representación compacta y funcional de paginación, y evaluar si la mascota decorativa añade valor en una vista operativa. **No** rediseñar por cambiar; comparar capturas antes/después y verificar el sistema de diseño. **Prueba:** review visual 320/390/768/1440, zoom 200 %, locales y accesibilidad.

### 7.3 Prioridades, límites y salida de aceptación

- **P0 confirmados:** 0. **P1 confirmado:** 0. **P2 abiertos o parciales:** 005, 010, 011, 012 (4); **P3:** 013 y recomendación visual 014 (2). El caso de permisos 008 queda como decisión de política y la cobertura 009 como puerta de verificación, no bug probado.
- **Secuencia:** solucionar 005 y 011; endurecer y probar 010; resolver 012; realizar el pulido 013/014 sin sacrificar accesibilidad; ejecutar pruebas de regresión y reevaluar **estos mismos IDs**.
- **Puertas:** RSpec focalizado, navegador con teclado y zoom, RuboCop, Brakeman, I18n, migración y schema-load desde cero, **CI global verde sobre SHA final**, revisión independiente y evidencia visual antes/después.
- **Estado:** REAUDITADO, NO CERRADO. No se realizaron adecuaciones funcionales en esta reauditoría, solo el seguimiento documental y el estándar de diseño.

## 8. Adecuaciones posteriores a la reauditoría — 2026-11-08

**Rama:** `feature/fixes`. **Estado:** cambios publicados, regresiones pendientes de aceptación final (no cerrado hasta CI y revisión independiente). Se mantienen los IDs originales, sin abrir tickets duplicados.

| Hallazgo | Resolución implementada | Regresión de aceptación |
|---|---|---|
| GENERAL_SETTINGS-005 | Cuando no existe configuración previa, el propio módulo ofrece una recuperación explícita de moneda activa, zona horaria, método de pago y tamaño de página; no redirige al Onboarding completado, y respeta la organización seleccionada. Registros previamente archivados siguen dando 404. | Organización completada sin ajuste, campos inválidos, A/B y rol administrativo por organización |
| GENERAL_SETTINGS-010 | La edición exige `expected_settings_updated_at` y comprueba la versión exacta dentro de `with_lock`; rechaza PATCH sin token y secuencias A→B→A mediante 409, sin guardar ni crear eventos. | Token omitido, conflicto tras cambio y vuelta al valor anterior, éxito con token válido |
| GENERAL_SETTINGS-011 | Se verifica `db/schema.rb` regenerado mediante Rails; el CI focalizado ahora exige que coincida con las migraciones y recrea la BD desde `db:schema:load`, comprobando tabla, `deleted_at`, FK y checks. Se preserva el snapshot actualizado por el trabajo concurrente de la plataforma. | Migración completa y reconstrucción limpia desde esquema versionado |
| GENERAL_SETTINGS-012 | Contraste de encabezados del ejemplo corregido de `text-slate-400` a `text-slate-600` (~7.6:1 sobre blanco); semántica de tabla de ejemplo y select accesible conservadas. | Inspección HTML y prueba visual/contraste en navegador cuando sea posible |
| GENERAL_SETTINGS-013 | El botón Guardar permanece deshabilitado cuando no hay cambios (con JS), muestra estado de cambios pendientes y se activa al elegir otra opción. El servidor también trata como no-op el PATCH idéntico sin anunciar actualización ni crear auditoría. | Navegador: elegir, volver al valor previo; request: no-op sin flash ni auditoría |
| GENERAL_SETTINGS-014 | Pulido visual sobrio: jerarquía de título, chip neutro de organización, panel informativo en gris, contraste y espaciado consistentes, vista previa descriptiva sin mascota decorativa, responsive sin overflow. | Reflujo en 320/390/512/768/1440; revisión visual manual pendiente |

**Política de permisos (GENERAL_SETTINGS-008):** los cambios recientes en el módulo propietario de Roles establecen permisos por organización: para administrar la segunda organización se requiere otorgamiento explícito del rol allí. La regresión de General incluye tanto el acceso con rol en B como el rechazo sin ese rol; no se alteran las reglas de Roles.

**Evidencia de iteración:** primera ejecución focalizada tras el cambio `74f99dbd`: YAML/I18n aprobado; RuboCop señaló ajustes menores y RSpec obtuvo 41 ejemplos, 3 fallos (fixtures de autorización organizacional y simulación artificial de zoom). Se corrigieron las ofensas de lint, se adecuaron los fixtures a la política vigente y se sustituyó CSS `style.zoom` por prueba de reflujo en viewport equivalente. **No adjudicar estado VERIFICADO a estas correcciones hasta su CI exitoso.**

**Límites:** no se han medido con lector de pantalla ni capturado antes/después con navegador local del usuario. La aprobación del CI focalizado no sustituye el CI global ni la revisión independiente del expediente; no se fusionó ninguna rama.

## 9. Verificación focalizada de todos los hallazgos recientes — 2026-11-08

**SHA funcional verificado:** `ce8dba740936d1e3b9207b5ef1fa807b11a0ad6b`.  
**General Settings CI:** https://github.com/AliRodri1992/sales_point/actions/runs/42566053882 — **SUCCESS**, tres jobs terminados satisfactoriamente.

| Control real | Resultado | Pruebas |
|---|---|---|
| RSpec del módulo y navegador Chrome | **42 ejemplos, 0 fallos** | Abarca recuperaciones, tenant, faltantes, formulario, conflictos A→B→A, cambios pendientes, reflujo 320/390/512/768/1440, contrato de paginación |
| RuboCop focalizado | **SUCCESS** | Solo archivos del módulo y su contrato |
| YAML y paridad i18n | **SUCCESS** | Configuración es/en/ko |
| Migraciones en BD nueva | **SUCCESS** | `bin/rails db:create db:migrate` |
| Schema versionado | **SUCCESS** | Compara la tabla y claves foráneas del audit de General con el dump de migraciones reales |
| Carga directa del schema | **SUCCESS** | `db:drop db:create db:schema:load` y comprobación de tabla, columna `deleted_at`, 2 FK y 2 check constraints |

**CI global de referencia:** https://github.com/AliRodri1992/sales_point/actions/runs/42566053707. La auditoría i18n, escaneo de seguridad y migraciones/semillas **PASARON**; RuboCop global **FALLÓ** con ofensas de Inventario, Onboarding, modelos compartidos, script y specs de módulos externos. El lint focal de General **no reporta ofensas**. RSpec global pendiente de conclusión en el momento de esta anotación. No trasladar esas ofensas internas externas al expediente de General: asignar seguimiento al propietario y mantener la puerta de cierre global bloqueada conforme al estándar.

**Revisión de calidad:** IDs GENERAL_SETTINGS-005, 010, 011, 012, 013 y 014 = **implementados y cubiertos por pruebas focalizadas**. El caso GENERAL_SETTINGS-008 de permisos se probó con roles por organización: segundo tenant con rol explícito permitido; segundo tenant sin rol administrativo rechazado. Los controles 001–004, 006 y 007 se mantuvieron. **PENDIENTE** evidencia manual de contraste visual con screenshots, lector de pantalla y revisión independiente formal. **No declarar cerrado** hasta CI completo verde y aprobación del expediente.

**Commits:** `74f99dbd` (funcionalidad/diseño), `0c3df3f7` (fixtures multi-organización, workflow y seguimiento), `a2a5cec0` (schema-load en job con Postgres), `ce8dba74` (comparación acotada al schema propio). Sin merge.

## 10. Reauditoría 2026-11-09 — General y contrato de preferencias

**Método:** AI Dev Suite (Impeccable, UI UX Pro Max, Ponytail), inspección dirigida de controlador, vistas, Stimulus, `delta-select`, modelo, validaciones, traducciones, política de usuario/organización, auditorías y migraciones; contraste con ejecución focalizada de GitHub Actions. El plugin aporta los procedimientos, no se ejecutó el detector CLI original.

**Código verificado:** `d414ec7d6380dd75675836c05b501391c010365f`, coincidente en archivos de General con el SHA `d1361e206189b2be4b0999e3f55fa3c2aea6dc61` (el único cambio intermedio fue documentación de Usuarios).

**Pruebas comprobadas (no supuestas):**
- [General Settings CI #42609076831](https://github.com/AliRodri1992/sales_point/actions/runs/42609076831): **SUCCESS**, 42 ejemplos y 0 fallos; RuboCop focal, I18n/YAML, migraciones, esquema, carga de schema, Chrome browser con cuatro anchos y reflujo equivalente a 200%.
- [CI global #42609077039](https://github.com/AliRodri1992/sales_point/actions/runs/42609077039): seguridad, I18n y migraciones/semillas aprobaron; RuboCop global **falló con 32 ofensas fuera de General** (Inventario, Onboarding, modelos compartidos, scripts y specs), RSpec global cancelado. **Bloquea cierre técnico** sin transferir responsabilidades.
- **Sin evidencia real:** capturas de antes/después, ejecución con lector de pantalla, teclado completo en los *tres* dropdowns de recuperación y prueba manual de zoom 200% en navegador. Las únicas pestañas de navegador disponibles eran conversaciones de ChatGPT, no la aplicación.

### GENERAL_SETTINGS-015 — P2 · PROPIO · nuevo · causa confirmada por código/framework, falta prueba request

**Campo `payment_method` inválido genera excepción en la recuperación.** En el camino sin configuración, `Admin::GeneralSettingsController#recover_settings` ejecuta `@settings.assign_attributes(recovery_params)` sin rescate, donde `recovery_params` permite `payment_method`. `OrganizationSetting` declara `enum :payment_method, { cash: 'cash', card: 'card', qr: 'qr' }` sin `validate: true`. Rails 8.1 lanza `ArgumentError` *al asignar* un valor no contemplado, antes de `@settings.save`; la validación de inclusión existente (contexto `create`) no llega a ejecutarse. **Escenario:** organización activa sin ningún ajuste previo, usuario administrador; enviar PATCH con moneda y zona válidas, y `organization_setting[payment_method]=crypto`. **Efecto esperado por las reglas del formulario:** 422 con error individual debajo de Método de pago y ningún registro creado. **Efecto deducido:** error no controlado en lugar de 422. **Causa:** enum estricto + entrada confiada a la asignación. **Acción:** configuración de enum con validación del modelo o normalización segura que preserve el mensaje de campo, sin ocultar los valores inválidos ni confiar en el HTML. **Regresión:** incluir valor fuera de catálogo, nil/cadena vacía, moneda inactiva y valor válido; verificar 422, contenido del error y que no haya escritura. **Estado:** pendiente; **no** se ejecutó esta solicitud contra una instancia. Referencia: documentación Rails 8.1 `ActiveRecord::Enum`.

### GENERAL_SETTINGS-016 — P3 · PROPIO · nuevo · inconsistencia de estado identificada por código, falta browser

**El preview anuncia un tamaño rechazado tras HTTP 422.** En la edición existente, PATCH con `default_table_page_size=99` deja `@settings` con atributo asignado no válido y errores; `show.html.erb` vuelve a dibujar el resumen de ejemplo con `count: @settings.default_table_page_size` (99). El selector solo ofrece 5/10/15/25/50, agrega una opción en blanco al haber error, y `general_settings_preview_controller.js#update` omite tamaños fuera de catálogo, por lo que no corrige el texto. **Efecto:** la tarjeta afirma «99 registros por página de forma predeterminada» aunque no se guardó la modificación. **Esperado:** nunca comunicar como predeterminado un valor inválido; usar el valor persistido o un estado de vista previa no disponible mientras se corrige el campo. **Regresión:** request 422 con 99 que compruebe el resumen, y browser al corregir la selección. **Estado:** pendiente.

### GENERAL_SETTINGS-009 — actualización de brecha de verificación

Conservar los 42 tests funcionales y de Chrome aprobados: la mejora es real y **no reabrir** lo ya verificado. Extender el escenario browser al modo recuperación (moneda/zona/método de pago con errores reales); probar teclado/escape/foco de cada dropdown, conflicto con reintento y cambio de idioma con nombres largos. Los controles manuales con lector de pantalla, captura visual y zoom *real* siguen sin acreditar. En el workflow focal, considerar incluir los cambios del componente `delta_select_controller.js` y `form_validation_helper.rb` como gatillos de CI, por su papel contractual directo.

### Evaluación y cierre

- **P0/P1 nuevos confirmados:** 0. **P2 nuevo:** 1 (`015`). **P3 nuevo:** 1 (`016`). **Puerta adicional:** `009` parcial por escenarios de accesibilidad no ejecutados.
- No se hallaron regresiones por código en `005` (recuperación con bloqueo de organización y respeto de ajustes archivados), `008` (permiso por organización), `010` (token obligatorio y bloqueo de fila), `011` (tabla de auditoría en schema), `012` (contraste), `013` (no-op/CTA) ni `014` (pulido existente).
- **Prioridad:** corregir `015` y `016` con pruebas negativas específicas; después cubrir `009` y obtener evidencia visual y CI global completo verde. **No cerrar el expediente** por el mero éxito del pipeline focal.
- **Esta reauditoría es documental:** no cambia controladores, modelos, formularios ni migraciones; únicamente agrega hallazgos al registro estable para adecuación posterior.
