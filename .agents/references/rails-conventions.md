# Convenciones Rails — Delta POS

## Stack observado
Rails 8.1.4+, Devise y devise-security, Pundit, PostgreSQL, Redis, Sidekiq, Hotwire/Turbo/Stimulus, ViewComponent, Tailwind 4, esbuild, Propshaft y Kamal aparecen en Gemfile/package.json.

## Método
1. Inspeccionar rutas, controlador, policy, modelos, servicios, vistas y specs del módulo antes de proponer capas nuevas.
2. Usar Rails idiomático y objetos con responsabilidades claras; SOLID/DRY/KISS/YAGNI son criterios, no excusa para sobreingeniería.
3. Verificar aislamiento por organización y permisos Pundit en acciones, queries y exportaciones.
4. Migraciones PostgreSQL: restricciones, índices y transacciones justificadas; evitar cambios destructivos sin plan.
5. Respetar es/en/ko y el registro de calidad modular `docs/quality/module-quality-standard.md`.

## Verificación
Comandos y resultados deben ser reales; usar `bash bin/overcommit-rspec` cuando el entorno local lo permita. CI no reemplaza revisión de comportamiento y viceversa.
