# Deltín — asistente visual de Delta POS

La integración está disponible en cualquier pantalla que usa `admin_dashboard`. El antiguo chat flotante de muestra ha sido reemplazado por un panel lateral inspirado en la propuesta aprobada.

## Primera versión funcional

- SVG vectorial local de un perrito naranja/blanco con headset azul y collar.
- Expresiones `idle`, `happy`, `thinking`, `concerned`, `laughing` y `talking`, mediante CSS y Stimulus.
- Boca animada **durante la lectura en voz alta** usando Web Speech API del navegador (solo después de pulsar «Leer en voz alta»).
- Panel adaptativo móvil/escritorio, apertura/cierre y navegación por teclado.
- Respuestas procedentes de los procedimientos realmente documentados en los YAML de la guía: no se generan explicaciones inexistentes ni se ejecutan acciones financieras.
- Control de sesión, organización activa, permisos por área (incluidos datos fiscales, bancos y finanzas), CSRF, restricciones de longitud y respuesta sin caché.
- No se envían datos a servidores de IA: el asistente es **guía contextual basada en reglas**; conectar un LLM externo requiere otra fase, autorización de envío de datos, configuración de proveedor y pruebas adicionales.

## Dónde se mantiene

- `app/views/admin/shared/_assistant.html.erb`: diseño del panel.
- `app/views/admin/shared/_deltin_mascot.html.erb`: dibujo SVG de la mascota.
- `app/assets/stylesheets/components/deltin.css`: expresiones, boca, parpadeo, patita, preferencias de movimiento reducido.
- `app/javascript/controllers/deltin_assistant_controller.js`: interacción y lectura de voz.
- `app/controllers/admin/assistant_controller.rb`: endpoint POST autenticado.
- `app/services/assistant/guide_responder.rb`: búsqueda en procedimientos de la guía según permisos.
- `config/locales/assistant.{es,en,ko}.yml`: textos.
- `spec/requests/admin/assistant_spec.rb`: pruebas.

Nota: los procedimientos detallados de los módulos están actualmente redactados en español y se reproducen sin traducción automática, aunque la interfaz del asistente admite español, inglés y coreano.

## Pruebas

`bundle exec rspec spec/requests/admin/assistant_spec.rb`

`bundle exec rubocop`

Se debe revisar CI antes de dar por validado el cambio.
