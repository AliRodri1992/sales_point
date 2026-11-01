# Guía visual de Delta POS

La ruta `/admin/guide` reúne los procedimientos de las funciones implementadas. Actualmente cuenta con 35 temas en siete capítulos y 78 procedimientos. Los pasos se mantienen en `config/locales/user_manual_*.es.yml`.

## Ilustraciones SVG locales

Cada procedimiento cuenta con un archivo SVG en `app/assets/images/guide/<id_del_tema>-<índice>.svg`. Los índices comienzan en 1 y siguen el orden de `tasks` en el tema. `overview.svg` muestra la ruta recomendada para los primeros pasos.

Cada diagrama indica visualmente **1. localizar el módulo, 2. realizar la operación y 3. comprobar el resultado**. Son representaciones didácticas, no capturas exactas: contienen datos ficticios y muestran de forma simplificada controles que pueden variar según la versión y los permisos. Las instrucciones de los procedimientos describen las reglas y comprobaciones particulares.

Si se agrega, elimina o reordena un procedimiento, también se deben añadir o actualizar sus SVG en la misma modificación. No incluir scripts, CDNs ni fuentes remotas en los SVG. Los diagramas se cargan en diferido mediante `image_tag` y pueden ampliarse desde un visor `dialog` accesible por teclado.

## Validación

Ejecuta `bundle exec rspec spec/requests/admin/user_guide_spec.rb` y `bundle exec rubocop`. El spec comprueba que cada procedimiento tenga una ilustración SVG local con metadatos accesibles, además del visor de ampliación.
