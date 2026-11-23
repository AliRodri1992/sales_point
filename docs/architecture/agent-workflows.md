# Flujos de agentes — Delta POS

## Principios
1. Leer `AGENTS.md` y confirmar rama activa autorizada antes de escribir; no asumir que `feature/fixes` seguirá siendo la rama futura.
2. Delimitar módulo usando `docs/quality/module-quality-standard.md`, expediente existente e índice.
3. Seleccionar solo las skills pertinentes, con las referencias de `.agents/references/`.
4. Inspeccionar código y tests; proponer el cambio mínimo; no inventar comportamiento ni colores.
5. Implementar, revisar diff, ejecutar controles aplicables y registrar evidencia; no declarar verificación sin ejecutar.

## Matriz de activación
| Tarea | Skills principales | Referencias |
|---|---|---|
| Nueva pantalla o mejora UI | ui-ux-designer, design-system-engineer, accessibility-specialist, testing-specialist | delta-emerald, ui-components, svg-iconography, testing-strategy |
| Modelo o flujo de negocio | rails-architect, database-specialist, security-auditor, testing-specialist | rails-conventions, security-checklist, testing-strategy |
| Integración externa | api-integration-specialist, security-auditor, observability-specialist, testing-specialist | security-checklist, testing-strategy |
| Jobs y tareas | background-jobs-specialist, observability-specialist, testing-specialist | rails-conventions, testing-strategy |
| Rendimiento | performance-optimizer, database-specialist, testing-specialist | rails-conventions, testing-strategy |
| Refactorización | refactoring-specialist, code-reviewer, testing-specialist | rails-conventions, testing-strategy |
| Traducciones | i18n-localization-specialist, accessibility-specialist, testing-specialist | ui-components, testing-strategy |
| Privacidad y permisos | data-privacy-specialist, security-auditor, testing-specialist | security-checklist |
| Dependencias y releases | dependency-maintenance-specialist, devops-engineer, release-management-specialist, git-workflow-specialist | testing-strategy, security-checklist |
| Documentación y PR | technical-documentation, code-reviewer, git-workflow-specialist | Referencias relacionadas con el cambio |

## Ejemplo piloto: pantalla de categorías (auditoría estática, no visual)
- Archivo de estilo inspeccionado: `app/assets/stylesheets/components/categories_workspace.css`.
- Se identificaron cabecera, botones, filtros, tabla, modal, estados vacíos, foco visible y layout móvil.
- Se observó uso de `var(--brand-on-white)` y `var(--brand-light)`, coherente con la tematización.
- Pruebas pendientes: renderizar pantalla en navegador, comprobar qué tema se aplica realmente, contrastes, interacción con teclado, estados de validación, es/en/ko y anchos 320/390/768/1440 px.
- Resultado: **inspección de código realizada; auditoría visual/funcional NO EJECUTADA**. No abrir ni cerrar hallazgos sin evidencias adicionales.

## Entrega
Registrar rama, SHA, archivos modificados, pruebas ejecutadas/no ejecutadas, hallazgos, riesgos y enlace a CI. Los commits de documentación no prueban comportamiento del sistema.

## Selección por superficie, riesgo y evidencia
| Señal | Skills pertinentes | Evidencia esperada |
|---|---|---|
| ERB, Tailwind, Stimulus, modales y ayuda contextual | `ui-ux-designer`, `design-system-engineer`, `accessibility-specialist`; `testing-specialist` para regresiones | Inventario antes/después, estados, teclado y responsive |
| Modelos, controladores, políticas y negocio | `rails-architect`, `testing-specialist`; sumar seguridad o base de datos según impacto | Contratos, permisos, casos negativos y specs |
| Migraciones, índices y catálogos | `database-specialist`, `testing-specialist` | Fuente de datos real, integridad y reversibilidad |
| Sidekiq, Redis y jobs | `background-jobs-specialist`, `testing-specialist` | Idempotencia, reintentos, errores y recuperación |
| CI, releases y dependencias | `devops-engineer`, `git-workflow-specialist`, `testing-specialist` | Logs, checks y resultados para el SHA |

### Contrato de revisión
1. Leer `AGENTS.md`, estándar y expediente del módulo; confirmar rama y SHA.
2. Documentar skills elegidas y motivo; no activar todas por disponibilidad.
3. Inventariar campos, acciones, catálogos, permisos, traducciones, estados y pruebas antes de cambiar.
4. Revisar el diff y las regresiones; incorporar `code-reviewer` para cambios de riesgo elevado.
5. Registrar resultados ejecutados y pendientes. Cuando se exija reporte antes de publicar, presentarlo antes del push.
