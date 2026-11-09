# Registro de calidad — General (`/admin/general_settings`)

**Estado:** AUDITADO POR INSPECCIÓN ESTÁTICA Y LECTURA DE PANTALLA; NO VERIFICADO; NO CERRADO.  
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
