# Estándar de calidad modular — Delta POS

**Aplicación:** todos los módulos actuales y futuros de Delta POS. **Versión:** 1.0.
**Responsable del cierre:** quien implementa la adecuación; una revisión independiente verifica las evidencias antes de declarar el módulo cerrado.
**Documentos:** [plantilla de auditoría](module-audit-template.md) · [primer registro: Sucursales](modules/branches.md).

## 1. Principio de alcance

- Una auditoría de módulo se define por sus rutas, pantallas y acciones **propias**, no por todas las asociaciones de su modelo.
- Se revisan sus vistas, componentes usados, formularios, controladores, permisos, modelos y servicios que implementan directamente esas acciones, mensajes y traducciones `es/en/ko`, más sus pruebas.
- Los módulos vecinos se evalúan **solo mediante contratos de integración observables desde el módulo auditado**: respuesta, autorización, restricción y retroalimentación de la acción propia.
- Un defecto interno identificado en otro módulo se registra como `EXTERNO`, con propietario y seguimiento independiente. **No se contabiliza como hallazgo interno** ni autoriza refactorizar indiscriminadamente el vecino.
- Solo se cambia código externo cuando la corrección del contrato lo exige y se deja explícita la justificación, el alcance y la prueba de integración.
- Antes de comenzar, consultar el registro existente. **No reiniciar hallazgos ni llamar «nuevo» a uno ya documentado**.

## 2. Flujo obligatorio para cada auditoría o adecuación

1. **Delimitar:** rutas y acciones incluidas/excluidas, dependencias en frontera, usuarios/roles, SHA inicial, pantallas y escenarios de uso.
2. **Inventariar:** rutas → controladores → permisos/modelos/servicios propios → vistas/JS/CSS → traducciones → specs. Verificar que las acciones y errores de cada pantalla estén representados.
3. **Auditar:** funcionalidad (altas, lecturas, cambios, borrado, errores, concurrencia), servidor/autorización/aislamiento, experiencia visual (desktop/móvil), accesibilidad, i18n y rendimiento cuando aplique.
4. **Registrar:** cada hallazgo recibe ID permanente, prioridad, evidencia reproducible (archivo/línea, paso, resultado esperado/observado), causa raíz, responsable y prueba de regresión requerida. Separar `confirmado` de `hipótesis por verificar`.
5. **Corregir:** atacar la causa raíz, preservar contratos, actualizar las pruebas que correspondan y mantener el cambio limitado al módulo. Antes de tocar un módulo vecino, documentar por qué es indispensable.
6. **Verificar:** comprobar sintaxis, tests focalizados, casos negativos, regresiones de interfaces y contratos, RuboCop, traducciones y CI global. Para UI, probar con navegador real cuando haya acceso.
7. **Reauditar:** verificar **los mismos hallazgos originales** más efectos secundarios, en el SHA publicado. Registrar cualquier falla nueva con su relación a los cambios previos.
8. **Cerrar o bloquear:** concluir únicamente cuando se cumplan los criterios de aceptación del punto 5. Si falta una herramienta o evidencia, dejar `pendiente de verificación`; nunca certificar resultados por inspección estática.

## 3. Matriz mínima de revisión por pantalla

| Dimensión | Comprobación |
|---|---|
| Estado y navegación | Carga, vacío, error de red/401/403/404/422, éxito, reintento, atrás/adelante, paginación y filtros cuando existan |
| Formularios | Reglas **del modelo/servidor**, campos obligatorios con asterisco rojo, mensajes individuales debajo del campo con formato «nombreCampo mensajeValidación», sin `required` HTML5 como sustituto y sin resumen duplicado de errores |
| Acceso e integridad | Autenticación, Pundit, aislamiento por organización, cambios concurrentes, estados prohibidos, soft delete y auditoría si aplican |
| Componentes | Identidad visual Delta POS, dropdowns propios sin radios internos, consistencia en botones, tooltips y confirmaciones SweetAlert2 según uso actual |
| Accesibilidad | Etiquetas, `aria-invalid` / `aria-describedby`, teclado/foco visible, lectores de pantalla, zoom 200 %, contraste y `prefers-reduced-motion` |
| Adaptabilidad e i18n | Anchuras móviles y escritorio, textos largos, locales `es`/`en`/`ko` y formatos correctos |
| Calidad y rendimiento | N+1, consultas, fallos de JavaScript, acciones repetidas/idempotencia, specs del módulo y límites de integración |

No marcar como verificado ningún escenario que no se haya ejecutado realmente.

## 4. Registro único y clasificación

Cada módulo dispone de `docs/quality/modules/<slug>.md`, creado a partir de la [plantilla](module-audit-template.md).
Mantener **un único registro por módulo**; usar enlaces a issues/PR si aportan seguimiento, pero no duplicar la fuente de verdad.

- **P0 Bloqueante:** riesgo crítico, ruptura de CI o del flujo esencial, exposición de datos, bloqueo global.
- **P1 Alto:** error funcional, autorización/aislamiento, pérdida o corrupción de datos, imposibilidad de completar una acción esencial.
- **P2 Medio:** degradación significativa de UX, accesibilidad, validaciones, rendimiento o errores recuperables.
- **P3 Pulido:** mejora estética o comodidad sin fallo de negocio.

Cada hallazgo distingue `confirmado por código`, `reproducido en pruebas/navegador` o `hipótesis`; incluye estado `abierto / en corrección / implementado sin verificar / verificado / cerrado / aceptado con riesgo`, responsable, test y SHA. Nunca cerrar un hallazgo solo por un commit.

## 5. Puertas de aceptación: implementado ≠ verificado ≠ cerrado

1. **Implementado:** cambio presente en GitHub, con commits y pruebas de regresión añadidas cuando corresponda; no supone que se ejecutaron.
2. **Verificado:** tests focalizados y escenarios manuales de las pantallas afectadas **realmente pasaron**, y la evidencia se vincula al **mismo SHA**.
3. **Cerrado:** sin P0/P1 abiertos, P2 resueltos o aceptados formalmente con justificación y propietario, pruebas funcionales y accesibilidad verificadas, **CI completo verde para el SHA de aceptación** y revisión final del registro.
4. Si el navegador, Docker o GitHub Actions no están disponibles, el módulo queda `implementado, pendiente de verificación` o `bloqueado`. No se usará «finalizado al 100 %».
5. **No fusionar** ramas a integración con checks requeridos fallidos o pendientes. Para hacer vinculante la puerta de CI, configurar protección de rama/rulesets con checks requeridos; un checklist por sí solo **no bloquea** un merge.

Verificar para el SHA final: **RSpec**, **RuboCop**, **Security scans**, **Rails I18n and YAML audit** y demás jobs requeridos por `.github/workflows/ci.yml` (incluidas migraciones limpias donde apliquen). Mantener los controles actuales; no introducir bypass de CI.

## 6. Evidencias y comandos

Registrar el comando, fecha, SHA, resultado, enlace/log y si la ejecución fue local o en GitHub Actions.
Para pruebas aisladas del repositorio:
- Focalizadas: `bash bin/overcommit-rspec spec/requests/admin/<modulo>_spec.rb` (sustituir por specs reales y añadir otras rutas aplicables).
- Suite completa: `bash bin/overcommit-rspec`.
- RuboCop: `docker compose -f docker-compose.dev.yml exec web bundle exec rubocop`.
- Seguridad: `docker compose -f docker-compose.dev.yml exec web bundle exec brakeman --no-pager`.
- CI y traducciones: consultar el job correspondiente en GitHub Actions para el **SHA** exacto.

Para UI, adjuntar evidencia de flujos reales y anchuras móvil/escritorio, errores por campo, foco y teclado. No inventar capturas ni resultados. Si un comando no pudo ejecutarse, anotar `NO EJECUTADO` y motivo.

## 7. Transferencias entre módulos y reapertura

- Contrato roto desde el módulo actual: registrar como **integración** y probar el límite. Error interno del vecino: abrir seguimiento **externo** con dueño, sin expandir su auditoría.
- Una prueba global fallida por código externo bloquea el **cierre técnico**, pero **no cambia la propiedad del hallazgo**.
- Reabrir cuando cambie el contrato, se rompa una prueba, CI dé rojo o una reproducción contradiga la evidencia. Conservar el ID y el historial, sin borrar registros anteriores.
- Durante el desarrollo de un módulo futuro (Onboarding, Terminales, Inventario, Compras), auditar su interior en **su propio registro** y reutilizar los contratos ya registrados sin duplicarlos.

## 8. Índice de módulos

| Módulo | Registro | Estado del proceso |
|---|---|---|
| Sucursales — `/admin/branches` | [Sucursales](modules/branches.md) | Auditoría base registrada; **pendiente de verificación y cierre** |
| Onboarding | Por crear al iniciar su auditoría | Sin cierre modular bajo este estándar |
| Terminales | Por crear al iniciar su auditoría | Sin cierre modular bajo este estándar |
| Inventario | Por crear al iniciar su auditoría | Sin cierre modular bajo este estándar |
| Purchases / Compras | Por crear al iniciar su auditoría | Sin cierre modular bajo este estándar |
| Demás módulos actuales o futuros | Usar la plantilla cuando se auditen | El estándar aplica desde ahora; no presumir auditorías realizadas |

Este estándar complementa `AGENTS.md` y el [checklist de Pull Request](../../.github/PULL_REQUEST_TEMPLATE.md); no reemplaza el CI ni las políticas de seguridad.