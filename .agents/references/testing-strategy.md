# Estrategia de pruebas y verificación

## Controles existentes
`.github/workflows/ci.yml` incluye jobs Security scans (Brakeman y Bundler Audit), RuboCop, RSpec, auditoría I18n/YAML y base nueva. RSpec incluye specs focalizados de N+1, proveedores, autenticación, sidebar y navegador.

## Para cada cambio
1. Elegir pruebas por comportamiento y riesgo: modelo, request, policy, servicio, job o sistema/browser.
2. Incluir casos negativos, permisos, aislamiento organizacional, errores, i18n y regresiones relevantes.
3. UI: estados normal/vacío/error/carga, teclado, móvil y escritorio; capturas solo si se obtuvieron realmente.
4. Registrar comando, SHA, resultado y entorno; no atribuir tests no ejecutados.
5. Si CI no se ejecuta en nuevas ramas por el filtro `push.branches`, usar PR/workflow_dispatch o actualizar configuración **con autorización**; no afirmar cobertura automática.

## Comandos documentados en el repositorio
- `bash bin/overcommit-rspec` para RSpec aislado en contenedor temporal.
- `docker compose -f docker-compose.dev.yml exec web bundle exec rubocop`.
- `docker compose -f docker-compose.dev.yml exec web bundle exec brakeman --no-pager`.
- `ruby script/audit_module_quality.rb`.

Estos comandos no se han ejecutado durante la creación de estas referencias.

## Matriz de pruebas según impacto
- Vista/JavaScript: specs de sistema/browser, navegación, estados carga/vacío/error, teclado/foco, 320/390/768/1440 px, zoom 200 % y es/en/ko.
- Controladores y policies: requests y policies para 401/403/404/422, roles y aislamiento organizacional.
- Modelos y servicios: límites, transacciones, N+1 y regresiones de contratos públicos.
- Jobs: idempotencia, reintentos, timeout, fallos y recuperación.
- Configuración y CI: sintaxis y ejecución de jobs sobre el SHA final; un YAML válido no demuestra un pipeline verde.
- Medir cobertura de líneas y ramas desde SimpleCov real; priorizar casos significativos, no cobertura artificial.
- Registrar comando, entorno, SHA, resultado, evidencia, pruebas no ejecutadas y motivo.
