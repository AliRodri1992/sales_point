# Checklist de seguridad Delta POS

- [ ] Devise: autenticación y flujos de recuperación adecuados.
- [ ] Pundit: autorizar acciones y alcance de consultas, sin IDOR entre organizaciones.
- [ ] Validación del servidor, CSRF, XSS, SQL injection y SSRF según superficie.
- [ ] Datos bancarios y personales: minimización, redacción de logs, permisos y exportaciones.
- [ ] Jobs y webhooks: autenticidad, reintentos idempotentes y secretos fuera del repositorio.
- [ ] Dependencias: `bin/brakeman --no-pager` y `bin/bundler-audit check --update` cuando el entorno permita.
- [ ] CSP y cabeceras revisadas sin debilitar protecciones existentes.
- [ ] Pruebas de denegación, casos negativos y aislamiento multi-tenant.
- [ ] Registrar severidad, evidencia, alcance, causa raíz y regresión en el expediente del módulo.

Ninguna casilla debe marcarse verificada sin ejecución o evidencia específica.
