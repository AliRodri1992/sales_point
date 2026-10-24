# Deltín — asistente visual de Delta POS

La integración está disponible en cualquier pantalla que usa `admin_dashboard`. El antiguo chat flotante de muestra ha sido reemplazado por un panel lateral inspirado en la propuesta aprobada.

## Primera versión funcional

- Imágenes oficiales de Deltín: retrato para el lanzador y mascota de cuerpo completo saludando para el panel. Ambos son SVG vectorizados con trazados reales sobre las ilustraciones aprobadas; no contienen imágenes incrustadas. La vectorización conserva formas y colores principales, aunque no es idéntica píxel por píxel a las imágenes originales.
- Estados animados `idle`, `happy`, `thinking`, `concerned`, `laughing` y `talking` con movimientos CSS sobre las ilustraciones originales. La versión estática del arte no dispone de capas faciales independientes; durante la lectura se anima suavemente el cuerpo (no hay lip-sync preciso de la boca).
- Lectura en voz alta opcional mediante Web Speech API, con animación de habla sincronizada con el inicio y fin de la locución.
- Panel adaptativo móvil/escritorio, apertura/cierre y navegación por teclado.
- El lanzador se oculta automáticamente mientras está abierto el formulario lateral de eventos del calendario, para no tapar los botones de guardar.
- Respuestas procedentes de los procedimientos realmente documentados en los YAML de la guía: no se generan explicaciones inexistentes ni se ejecutan acciones financieras.
- Control de sesión, organización activa, permisos por área (incluidos datos fiscales, bancos y finanzas), CSRF, restricciones de longitud y respuesta sin caché.
- No se envían datos a servidores de IA: el asistente es **guía contextual basada en reglas**; conectar un LLM externo requiere otra fase, autorización de envío de datos, configuración de proveedor y pruebas adicionales.

## Dónde se mantiene

- `app/views/admin/shared/_assistant.html.erb`: diseño del panel.
- `app/assets/images/deltin/{portrait,waving}.svg`: arte oficial para botón y panel.
- `app/assets/stylesheets/components/deltin.css`: movimiento de los estados de ánimo y preferencias de movimiento reducido.
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

## Fuente vectorial

Los SVG de `app/assets/images/deltin/` contienen únicamente formas `path` rellenas con colores sólidos; no existen referencias a imágenes `<image>` ni datos PNG/WebP incrustados. La silueta corresponde a las dos poses aprobadas y conserva las dos orejas. Los retratos son ilustraciones vectorizadas a partir de los originales y simplifican parte de los degradados finos. Los estados de ánimo actuales transforman el gráfico completo; las piezas faciales individuales requerirían una recreación por capas específica para lograr sincronización labial precisa.
