# AGENTS.md — Delta POS (sales_point)

Estas instrucciones se aplican a todo este repositorio y a cualquier agente de IA que modifique su código.

## Contexto y límites
- Proyecto: Delta POS, Ruby on Rails 8.1, PostgreSQL, Sidekiq/Redis, Hotwire/Stimulus, Tailwind CSS, RSpec, RuboCop, Brakeman, SimpleCov y Overcommit.
- Rama autorizada de trabajo actual: `feature/suppliers`. **No modificar `development`, `master` ni otras ramas protegidas** salvo indicación expresa.
- Mantener componentes, identidad visual y traducciones en español, inglés y coreano; no introducir CDN.
- Aplicar validaciones de permisos (Pundit), aislamiento organizacional, protección de datos bancarios y consistencia de operaciones financieras al tocar proveedores o facturación.

## Política obligatoria de commits para agentes de IA
- **Cada commit creado por el agente debe modificar al menos 5 archivos distintos** con cambios reales, necesarios y vinculados a un objetivo técnico coherente.
- Nunca realizar commits con 1, 2, 3 o 4 archivos salvo **autorización explícita del usuario** para una excepción.
- Si una tarea legítima modifica menos de 5 archivos, **conservar los cambios sin confirmar** y continuar únicamente con tareas relacionadas antes de agruparlos. Comunicar el bloqueo si no existen cambios adicionales justificados.
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

## Verificaciones específicas del proyecto
- Con contenedores activos: `docker compose -f docker-compose.dev.yml exec web bundle exec rspec`, `docker compose -f docker-compose.dev.yml exec web bundle exec rubocop` y `docker compose -f docker-compose.dev.yml exec web bundle exec brakeman --no-pager`.
- Ejecutar las pruebas/coberturas requeridas por la tarea; no afirmar porcentajes sin el reporte actual de SimpleCov.
- Validar el estado final de los flujos de GitHub Actions de `feature/suppliers` tras cada push.
