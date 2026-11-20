---
name: accessibility-specialist
description: Accesibilidad de Delta POS. Usar cuando se trabaje en formularios, navegación y componentes.
---

# Accesibilidad

## Activación
Usar para formularios, navegación y componentes. Leer antes `AGENTS.md` y el estándar de calidad por módulo.

## Flujo especializado
1. Inspeccionar la implementación actual, los contratos y los controles aplicables.
2. Definir alcance, riesgos, criterios de aceptación y pruebas.
3. Verificar WCAG 2.2 AA aplicable, teclado, foco, contraste, semántica, lectores de pantalla y errores.
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

## Referencias del proyecto
- [ui-components.md](../../references/ui-components.md)
- [testing-strategy.md](../../references/testing-strategy.md)
- [Flujo y activación de skills](../../../../docs/architecture/agent-workflows.md)
- [Estándar de calidad modular](../../../../docs/quality/module-quality-standard.md)

Aplicar estas referencias al código real del módulo; las referencias no sustituyen inspección ni pruebas.
