---
name: rails-architect
description: Arquitectura Rails para Delta POS. Activar ante cambios en modelos, controladores, servicios, rutas o límites de dominio.
---

# Arquitectura Rails

## Cuándo utilizar
cambios en modelos, controladores, servicios, rutas o límites de dominio.

## Objetivo
Revisar rutas, modelos y flujos actuales; privilegiar Rails idiomático y responsabilidades claras; usar objetos de servicio o consulta solo si simplifican; verificar aislamiento organizacional y compatibilidad.

## Identidad visual Delta Emerald
- Respetar los tokens y componentes existentes de Delta Emerald. Interfaces profesionales, contemporáneas, elegantes, sobrias, responsive y accesibles; no inventar paleta ni cambiar la identidad.

## Reglas obligatorias
- Antes de actuar, leer `AGENTS.md`, `docs/quality/module-quality-standard.md` y documentación específica del módulo cuando aplique.
- Confirmar la rama activa autorizada antes de escribir. No modificar `master`, `development` ni ramas protegidas sin permiso; no cambiar de rama automáticamente.
- Inspeccionar implementación existente antes de agregar gemas, paquetes, abstracciones o archivos.
- Respetar Rails 8.1, PostgreSQL, Tailwind CSS 4, Hotwire/Stimulus, ViewComponent, RSpec y los controles CI actuales.
- Mantener permisos Pundit, aislamiento organizacional, privacidad y locales es/en/ko.
- Registrar evidencia de pruebas y CI; si no se ejecutaron, indicarlo claramente.
- No usar bibliotecas de iconos (incluido Lucide). Los iconos de interfaz deben ser SVG originales inline dentro del HTML/ERB generado.

## Procedimiento
1. Identificar alcance y archivos involucrados; revisar contratos con módulos vecinos sin ampliar auditorías innecesariamente.
2. Definir riesgos, criterios de aceptación y pruebas antes de editar.
3. Implementar el cambio mínimo compatible con convenciones del repositorio.
4. Ejecutar verificaciones relevantes y documentar comandos, resultados y limitaciones.
5. Revisar diff, seguridad, accesibilidad e i18n según el cambio; actualizar documentación de calidad del módulo cuando corresponda.

## Lista de verificación especializada
- Revisar rutas, modelos y flujos actuales; privilegiar Rails idiomático y responsabilidades claras; usar objetos de servicio o consulta solo si simplifican; verificar aislamiento organizacional y compatibilidad.
- Arquitectura mínima justificada, contratos explícitos y pruebas de regresión.
- No declarar aceptación hasta confirmar las verificaciones aplicables al SHA final.

## Entregables
- Resumen del cambio o auditoría y justificación.
- Pruebas ejecutadas, pendientes y resultados.
- Riesgos residuales y referencias a archivos o documentación.

## Referencias del proyecto
- [rails-conventions.md](../../references/rails-conventions.md)
- [testing-strategy.md](../../references/testing-strategy.md)
- [Flujo y activación de skills](../../../../docs/architecture/agent-workflows.md)
- [Estándar de calidad modular](../../../../docs/quality/module-quality-standard.md)

Aplicar estas referencias al código real del módulo; las referencias no sustituyen inspección ni pruebas.
