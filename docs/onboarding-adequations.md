# Adecuaciones de la configuración inicial

Pantalla: `/admin/onboarding`. Rama: `feature/fixes`.

## Alcance

Se conserva la identidad de Delta POS y se modifica únicamente el contenido y comportamiento del onboarding y los servicios que lo guardan. No se modifican vistas ni controladores de sidebar, navbar/topbar, layout administrativo, asistentes flotantes o pie compartido. El porcentaje que muestran otros componentes continúa procediendo del cálculo real de configuración.

Los enlaces documentales del pie administrativo compartido, identificados en la auditoría previa, quedan fuera de esta entrega para respetar el alcance por pantalla.

## Interfaz

- Cabecera compacta con progreso accesible y explicación de guardado progresivo.
- Pasos horizontales en escritorio y selector desplegable en móvil; estado actual, completo o pendiente y `aria-current`.
- Formularios con controles uniformes, colores de acción y etiquetas de mayor contraste, límites del modelo y mensajes «NombreCampo mensajeValidación».
- Errores asociados mediante `aria-describedby` y `aria-invalid`; foco en el primer control inválido. Los selectores DeltaSelect se montan explícitamente en esta pantalla y conservan su comportamiento tras respuestas 422.
- Navegación con confirmación para descartar cambios pendientes. El borrador se compara únicamente en memoria; no se guarda información de formularios en localStorage o sessionStorage. Se evita almacenar una copia Turbo de la pantalla para no recuperar cambios descartados al volver atrás.
- Guardar y continuar / Guardar y salir; estados de envío, error de red y HTTP, conservación del formulario y aviso SweetAlert2 persistente con cierre manual.
- Resumen con enlaces a las secciones reales y pendientes concretos. Reinicio en acciones secundarias con explicación de los datos que conserva.
- Traducciones de la nueva interfaz en español, inglés y coreano.

## Correcciones funcionales

El método inicial de pago se trata como una preferencia: guardar Tarjeta conserva una integración activa y elegir Efectivo no desconecta proveedores. Una integración nueva o que requiere configuración permanece pendiente; el onboarding no simula una conexión operativa con un proveedor.

Los requisitos de dirección y el porcentaje de sucursal siguen las reglas del país seleccionado. Las cajas de sucursales inactivas no cuentan como operativas. El registro de auditoría asigna los pasos a negocio, sucursal, cajas y pagos; los cambios de país registran su identificador real.

Los nombres de cajas existentes se conservan si no se envía una sustitución. Un nombre vacío se rechaza mediante validación en lugar de reemplazarse silenciosamente por un nombre predeterminado.

Para registros anteriores incompletos, la misma pantalla permite guardar una sucursal inicial, crear explícitamente la primera caja activa y completar el perfil del responsable con el correo de la cuenta actual. La creación de caja y perfil utiliza bloqueo de la organización, evita duplicados, conserva registros eliminados/inactivos y registra la acción. No concede roles ni permisos nuevos, ni permite seleccionar una organización o cuenta ajena mediante parámetros del formulario. Un perfil inactivo existente requiere revisión administrativa y no se reactiva automáticamente.

## Verificación

Se utilizan pruebas de servicios, solicitudes y navegador en el contenedor temporal del proyecto, con base de datos de pruebas. Se comprueban pagos, progreso por país, creación sin duplicados, nombres de cajas, permisos, aislamiento entre organizaciones, finalización, errores 422, red/503, conservación de cambios, móvil y los tres idiomas. Se incluyen regresiones del registro, del que procede la configuración inicial.

Comando de la suite pertinente:

```sh
bash bin/overcommit-rspec --require rails_helper spec/services/onboarding spec/requests/admin/onboarding_spec.rb spec/requests/admin/onboarding_controller_spec.rb spec/requests/admin/onboarding_usability_spec.rb spec/policies/onboarding_policy_spec.rb spec/features/onboarding_usability_browser_spec.rb spec/services/registration_service_spec.rb
```

También se ejecutan RuboCop, Brakeman, compilación de CSS/JavaScript y auditoría I18n estricta. Los escenarios de creación y cambios de configuración se verifican en la base de pruebas; la revisión visual no necesita crear registros de operación en desarrollo. No se realiza push ni se atribuyen verificaciones locales a GitHub Actions.

Resultado local final: **127 ejemplos, 0 fallos**, semilla 15321; RuboCop sin observaciones en 33 archivos inspeccionados; Brakeman con 0 advertencias y 0 errores; auditoría I18n estricta aprobada en 222 archivos; compilaciones CSS y JavaScript completadas. La comprobación de 320×740 usa las dimensiones del viewport, compensando el marco de la ventana de Selenium, y verifica que el primer campo completo sea visible. Se conserva el aviso de compilación existente de intl-tel-input sobre `@position-try`, que no impide generar CSS.
