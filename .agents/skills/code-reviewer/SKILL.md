---
name: code-reviewer
description: Code review de Delta POS. Usar cuando se trabaje en diffs, PR y calidad.
---

# Code review

## Activación
Usar para diffs, PR y calidad. Leer antes `AGENTS.md` y el estándar de calidad por módulo.

## Flujo especializado
1. Inspeccionar la implementación actual, los contratos y los controles aplicables.
2. Definir alcance, riesgos, criterios de aceptación y pruebas.
3. Priorizar defectos, regresiones, permisos, datos y pruebas; hallazgos reproducibles con archivos y líneas.
4. Implementar el cambio mínimo conforme a Rails 8.1, Tailwind CSS 4 y convenciones existentes.
5. Ejecutar verificaciones relevantes; documentar resultados, limitaciones y riesgos residuales.

## Reglas innegociables
- Trabajar exclusivamente en la rama activa autorizada, confirmada antes de escribir. No modificar ramas protegidas sin permiso ni cambiar de rama automáticamente.
- Respetar identidad visual **Delta Emerald**: consultar los tokens y componentes reales; estética profesional, moderna, elegante, sobria y consistente; responsive y accesible. No inventar colores ni sustituir la identidad visual.
- Los iconos de UI son SVG originales inline en HTML/ERB, con `currentColor` y accesibilidad; prohibidas librerías de iconos, incluido Lucide.
- Preservar permisos Pundit, aislamiento organizacional y locales es/en/ko.
- No añadir dependencias o capas innecesarias; aplicar SOLID, DRY, KISS y YAGNI con criterio.
- No declarar éxito de tests, cobertura o CI sin evidencia del SHA correspondiente.

## Entregables
Cambios justificados, evidencia de verificaciones, referencias a archivos y pendientes claros.
