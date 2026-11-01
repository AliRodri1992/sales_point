# Auditoría de claridad de mensajes y estados de Delta POS
Fecha: 31 de octubre de 2026. Rama: `feature/suppliers`.

## Criterio UX
El usuario debe poder identificar (1) qué ocurrió, (2) a qué registro o sección corresponde y (3) cómo continuar si necesita actuar. Un título o estado breve puede ser correcto por sí solo; no debe reemplazarse indiscriminadamente por un párrafo. Los errores no deben sugerir pérdida de datos sin evidencia. Las bajas lógicas deben distinguirse de la destrucción irreversible.

## Correcciones realizadas
Se revisaron y mejoraron mensajes y estados de:
- Actividad de contactos y direcciones del proveedor.
- Guardado y errores del dashboard.
- Mensajes de carga y progreso de acciones administrativas.
- Confirmaciones, errores y cambios de dirección principal del expediente de proveedores.
- Calendario de proveedores: eventos, ausencia de horarios y actividades, recuperación.
- Edición de perfil y gestión de usuarios.
- Cargas paginadas de contactos y direcciones.
- Cuentas por pagar y sus estados sin resultados.
- Altas y modificaciones de clientes, proveedores y ofertas de productos.
- Listados de compras sin resultados.
- Documentos del proveedor, permisos por rol, errores del asistente IA.
- Excepciones de calendario y recuperación de proveedores inactivos.
- Traducción completa de `config/locales/clients.ko.yml`, que conservaba textos visibles en inglés.

Las redacciones se actualizaron de manera coordinada en `es` (español mexicano), `en` y `ko`.

## Control automatizado nuevo
`script/audit_ux_messages.py` recorre todos los archivos YAML de `config/locales`, identifica mensajes de éxito, error y estados vacíos demasiado breves o vacíos, y revisa candidatos a alertas y mensajes incrustados en `app/controllers`, `app/views`, `app/javascript`, `app/helpers` y `app/services`.

El script se añadió al job de I18n de GitHub Actions. Sus hallazgos son **avisos para revisión contextual**, no fallos automáticos, para evitar marcar como incorrectas etiquetas breves legítimas como «Activo» o «Cancelar».

`spec/i18n/actionable_messages_spec.rb` protege mensajes de actividad del proveedor y los resultados del calendario contra regresiones a textos vacíos o triviales.

## Límites y estado de cierre
La revisión y las correcciones abarcan los mensajes identificados en los catálogos y módulos indicados, **no constituyen certificación de que absolutamente todo mensaje de la aplicación sea correcto**. Aún se necesita revisar los candidatos restantes del nuevo auditor y ejecutar pruebas de navegador para confirmar contexto, longitud, accesibilidad, superposición, localización por idioma y estados de error de cada flujo. Las traducciones dinámicas almacenadas en base de datos deben comprobarse con datos reales de la instalación.

La condición de cierre integral es: auditar los candidatos restantes, corregir los falsos textos o mensajes incompletos relevantes y aprobar GitHub Actions de un mismo HEAD con RSpec, RuboCop, seguridad e internacionalización.

La última ejecución de CI debe consultarse en GitHub Actions para ver su estado efectivo; no se presume aprobada por el hecho de haber publicado commits.
