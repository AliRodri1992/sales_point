# AGENTS.md — Delta POS (sales_point)

Estas instrucciones se aplican a todo este repositorio y a cualquier agente de IA que modifique su código.

## Contexto y límites
- Proyecto: Delta POS, Ruby on Rails 8.1, PostgreSQL, Sidekiq/Redis, Hotwire/Stimulus, Tailwind CSS, RSpec, RuboCop, Brakeman, SimpleCov y Overcommit.
- Rama autorizada de trabajo actual: `feature/suppliers`. **No modificar `development`, `master` ni otras ramas protegidas** salvo indicación expresa.
- Mantener componentes, identidad visual y traducciones en español, inglés y coreano; no introducir CDN.
- Aplicar validaciones de permisos (Pundit), aislamiento organizacional, protección de datos bancarios y consistencia de operaciones financieras al tocar proveedores o facturación.

## Política de commits

- Los commits pueden modificar **cualquier cantidad de archivos**, incluidos commits de un solo archivo. No existe un mínimo de archivos ni una excepción especial para `db/schema.rb`.
- Cada commit debe ser coherente, revisable y limitado a cambios justificados por la tarea. No introducir cambios artificiales.
- Antes de publicar, ejecutar las pruebas y analizadores aplicables. Tras el push, consultar GitHub Actions y corregir fallos; no declarar éxito sin verificar.
- Si existe un cambio de rama concurrente, no sobrescribir trabajo de otros agentes. No forzar el push sobre una rama compartida.

## Instalación/verificación local de Overcommit

El hook de Overcommit se instala con `bundle exec overcommit --install` y se firma con `bundle exec overcommit --sign`. Se mantienen RuboCop y los demás controles de calidad; **no** existe una verificación de cantidad de archivos por commit.

## Seguridad y calidad
- No guardar claves, tokens ni datos personales en Git; revisar diffs y archivos generados.
- Conservar convenciones existentes, permisos/autorización, pruebas, accesibilidad, estilos e internacionalización.
- Si un comando no pudo ejecutarse por limitaciones del entorno, informar qué falta verificar, sin declarar éxito ficticio.

## Contrato de Overcommit y validación completa

- **PreCommit**: únicamente `TrailingWhitespace`; no ejecutar herramientas lentas.
- **PrePush**: RSpec, Brakeman, BundlerAudit y BundleCheck están desactivados
  localmente. Los pushes no deben invocar Docker ni bloquearse por la base test.
- **CI** (`.github/workflows/ci.yml`): mantiene toda la suite RSpec, RuboCop,
  Brakeman, BundlerAudit y auditoría I18n. Un fallo debe seguir marcando rojo.
- `test/overcommit_configuration_test.rb` valida esta separación y se ejecuta
  en el workflow de hooks junto con la prueba del runner manual.
- El runner `bin/overcommit-rspec` queda disponible **solo para ejecución manual**,
  y siempre usa un contenedor efímero vía `docker compose run --rm -T web`.
  Nunca debe modificar la base de desarrollo ni recurrir al Rails del host.
- No utilizar `--no-verify` ni desactivar comprobaciones del workflow CI.
- Para prohibir integrar CI rojo, configurar los checks requeridos de la rama
  en GitHub: esta restricción se aplica a los merges, no bloquea el push.
- Tras un cambio, verificar los resultados del CI del SHA publicado antes de
  afirmar que todas las pruebas pasaron.

## Verificaciones específicas del proyecto
- Para RSpec local ejecutar manualmente `bash bin/overcommit-rspec` (contenedor temporal). Con contenedores activos, ejecutar RuboCop y Brakeman mediante `docker compose -f docker-compose.dev.yml exec web bundle exec rubocop` y `docker compose -f docker-compose.dev.yml exec web bundle exec brakeman --no-pager`.
- Ejecutar las pruebas/coberturas requeridas por la tarea; no afirmar porcentajes sin el reporte actual de SimpleCov.
- Validar el estado final de los flujos de GitHub Actions de `feature/suppliers` tras cada push.
