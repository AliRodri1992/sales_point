# AGENTS.md — Delta POS (sales_point)

Estas instrucciones se aplican a todo este repositorio y a cualquier agente de IA que modifique su código.

## Contexto y límites
- Proyecto: Delta POS, Ruby on Rails 8.1, PostgreSQL, Sidekiq/Redis, Hotwire/Stimulus, Tailwind CSS, RSpec, RuboCop, Brakeman, SimpleCov y Overcommit.
- Rama autorizada de trabajo actual: `feature/suppliers`. **No modificar `development`, `master` ni otras ramas protegidas** salvo indicación expresa.
- Mantener componentes, identidad visual y traducciones en español, inglés y coreano; no introducir CDN.
- Aplicar validaciones de permisos (Pundit), aislamiento organizacional, protección de datos bancarios y consistencia de operaciones financieras al tocar proveedores o facturación.

## Política obligatoria de commits para agentes de IA
- **Cada commit creado por el agente debe modificar al menos 5 archivos distintos** con cambios reales, necesarios y vinculados a un objetivo técnico coherente, salvo la excepción exclusiva del esquema descrita abajo.
- **Única excepción autorizada sin consultar:** un commit de exactamente **un archivo**, que modifique exclusivamente `db/schema.rb` ya existente, y solamente cuando sea necesario actualizar el esquema real de la base de datos tras cambios legítimos del modelo de datos. Confirmar previamente que el diff es una actualización correcta generada por Rails; la comprobación automática verifica la ruta y que el estado Git sea modificación (M), pero no puede verificar por sí sola la necesidad técnica.
- **Nunca** crear commits de 2, 3 o 4 archivos, aunque uno de ellos sea el esquema. Tampoco admitir commits individuales de otros archivos, ni crear, renombrar o eliminar `schema.rb` como excepción.
- Si una tarea legítima modifica de 1 a 4 archivos y no encaja en la única excepción, **conservar los cambios sin confirmar** y agrupar únicamente trabajo relacionado. Comunicar el bloqueo si no hay modificaciones adicionales justificadas.
- Cualquier otra excepción distinta debe recibir autorización explícita del usuario.
- No cambiar archivos arbitrarios, generar archivos vacíos ni incluir retoques cosméticos para llegar a cinco.
- No confundir archivos cambiados con líneas: cuentan rutas de archivo diferentes, incluidas altas, cambios, renombres y bajas.
- Commits coherentes y revisables: no unir funcionalidades independientes solo por cumplir un número.
- Antes de confirmar, revisar `git status`, `git diff --cached` y ejecutar `bash bin/check-commit-min-files --staged`. El hook `MinimumCommitFiles` de Overcommit automatiza la verificación en el equipo local.
- Antes de publicar, ejecutar los tests y analizadores aplicables. Tras publicar, consultar GitHub Actions y corregir fallos; nunca afirmar que todo pasó sin resultados comprobados.
- GitHub Actions ejecuta `.github/workflows/commit-policy.yml` para verificar commits nuevos; los commits de fusión se exceptúan de esta comprobación de tamaño, no de las demás pruebas.
- Es posible eludir hooks locales con comandos especiales; eso **no concede autorización** para hacer commits pequeños.
- Si existe un cambio de rama concurrente, no sobrescribir trabajo de otros agentes. Nunca forzar `push` sobre una rama compartida.

## Instalación/verificación local del hook
Tras obtener esta configuración o cuando Overcommit lo solicite, ejecutar `bundle exec overcommit --install` y `bundle exec overcommit --sign` desde la raíz del repositorio. La verificación manual es `bash bin/check-commit-min-files --staged`; las pruebas aisladas del verificador son `bash test/commit_min_files_test.sh`.

## Seguridad y calidad
- No guardar claves, tokens ni datos personales en Git; revisar diffs y archivos generados.
- Conservar convenciones existentes, permisos/autorización, pruebas, accesibilidad, estilos e internacionalización.
- Si un comando no pudo ejecutarse por limitaciones del entorno, informar qué falta verificar, sin declarar éxito ficticio.

## Pre-push y pruebas RSpec locales

- `bin/overcommit-rspec` usa únicamente `docker compose -f docker-compose.dev.yml`. No añadir fallback de Rails ejecutado en el host: `db` solo se resuelve en la red Compose.
- Si `web` está activo, ejecutar vía `exec -T`; si está detenido, `run --rm -T` debe iniciar las dependencias. Ambas rutas fuerzan `RAILS_ENV=test`, preparan la base de pruebas y eliminan `DATABASE_URL`.
- Fallos del daemon, Compose, PostgreSQL o RSpec deben detener el push y propagarse; nunca utilizar `--no-verify` como solución.
- Antes de cambiar el hook, ejecutar `bash test/overcommit_rspec_test.sh`, que simula las rutas con y sin contenedor y fallos de Docker sin conectarse a servicios externos. CI ejecuta este verificador en `.github/workflows/commit-policy.yml`.
- Tras actualizar el hook en una máquina local, revisar el script y volver a firmar con `bundle exec overcommit --sign pre-push` si Overcommit lo solicita.

## Verificaciones específicas del proyecto
- Con contenedores activos: `docker compose -f docker-compose.dev.yml exec web bundle exec rspec`, `docker compose -f docker-compose.dev.yml exec web bundle exec rubocop` y `docker compose -f docker-compose.dev.yml exec web bundle exec brakeman --no-pager`.
- Ejecutar las pruebas/coberturas requeridas por la tarea; no afirmar porcentajes sin el reporte actual de SimpleCov.
- Validar el estado final de los flujos de GitHub Actions de `feature/suppliers` tras cada push.
