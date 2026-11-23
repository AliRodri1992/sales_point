# Pruebas y cobertura de Delta POS

Desde la raíz del repositorio, con Docker disponible y el [entorno de desarrollo preparado](installation.md), ejecuta el [runner manual](../bin/overcommit-rspec). Cada ejecución crea un contenedor temporal, prepara la base de pruebas y devuelve el código de salida de RSpec.

| Objetivo | Comando |
| --- | --- |
| Ejecutar toda la suite | `bash bin/overcommit-rspec` |
| Probar un modelo | `bash bin/overcommit-rspec spec/models/product_spec.rb` |
| Reproducir un orden de ejecución | `bash bin/overcommit-rspec --seed 56221` |
| Generar el reporte de SimpleCov | `COVERAGE=true bash bin/overcommit-rspec` |

El runner usa por defecto la base `sale_point_test`, Redis en la base lógica 15 y un bloqueo para coordinar el acceso a la base de pruebas. Abre `coverage/index.html` al finalizar con cobertura. Para informar la cobertura del proyecto, usa el reporte de una ejecución de la suite completa.

## Analizadores y controles

Con el servicio `web` activo:

```sh
docker compose -f docker-compose.dev.yml exec web bundle exec rubocop
docker compose -f docker-compose.dev.yml exec web bundle exec brakeman --no-pager
```

Overcommit comprueba espacios sobrantes al crear el commit. Para instalar y firmar los hooks usa `bundle exec overcommit --install` y `bundle exec overcommit --sign`. La [configuración de hooks](../.overcommit.yml) deja la suite completa a cargo de [GitHub Actions](../.github/workflows/ci.yml), que también ejecuta RuboCop, análisis de seguridad, auditoría de I18n y comprobaciones de migraciones y semillas. Consulta el resultado del SHA publicado para conocer el estado del cambio.
