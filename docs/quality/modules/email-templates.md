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
