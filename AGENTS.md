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

## Pre-push y pruebas RSpec locales

- `bin/overcommit-rspec` usa únicamente `docker compose -f docker-compose.dev.yml`. No añadir fallback de Rails ejecutado en el host: `db` solo se resuelve en la red Compose.
- El hook usa **siempre** `docker compose run --rm -T web` para ejecutar RSpec en un contenedor temporal aislado, incluso cuando `web` ya está activo. No usar `docker compose exec web` para la suite completa: los procesos de prueba y Chromium podrían agotar los recursos del servidor activo. Fuerza `RAILS_ENV=test`, prepara la base de pruebas y elimina `DATABASE_URL`.
- Fallos del daemon, Compose, PostgreSQL o RSpec deben detener el push y propagarse; nunca utilizar `--no-verify` como solución.
- Si se modifica el hook, validar `bash test/overcommit_rspec_test.sh`, que simula la ejecución aislada y fallos de Docker sin conectarse a servicios externos. CI ejecuta este verificador en `.github/workflows/pre-push-hook-tests.yml`.
- Tras actualizar el hook en una máquina local, revisar el script y volver a firmar con `bundle exec overcommit --sign pre-push` si Overcommit lo solicita.

## Verificaciones específicas del proyecto
- Para RSpec local usar `bin/overcommit-rspec` (contenedor temporal). Con contenedores activos, ejecutar RuboCop y Brakeman mediante `docker compose -f docker-compose.dev.yml exec web bundle exec rubocop` y `docker compose -f docker-compose.dev.yml exec web bundle exec brakeman --no-pager`.
- Ejecutar las pruebas/coberturas requeridas por la tarea; no afirmar porcentajes sin el reporte actual de SimpleCov.
- Validar el estado final de los flujos de GitHub Actions de `feature/suppliers` tras cada push.
