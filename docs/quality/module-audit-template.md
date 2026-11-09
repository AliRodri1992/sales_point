# Registro de calidad: [MÓDULO]

> Copiar este archivo a `docs/quality/modules/[slug].md`. El registro **pertenece al módulo**, no a toda la plataforma. No marcar estados como aprobados si falta evidencia.

- **Módulo y ruta principal:** [nombre] — [ruta]
- **Rutas y acciones propias incluidas:** [listar]
- **Rutas/módulos fuera de alcance:** [listar]
- **Contratos externos indispensables:** [entrada / respuesta / errores / módulo propietario]
- **Responsable y revisión independiente:** [personas/roles]
- **SHA de partida:** [sha]
- **SHA auditado:** [sha]
- **SHA de aceptación:** PENDIENTE
- **Estado del módulo:** AUDITADO / EN CORRECCIÓN / IMPLEMENTADO PENDIENTE / VERIFICADO / CERRADO / BLOQUEADO
- **Última revisión y evidencia:** [fecha / enlace / comando]

## Mapa de alcance

| Ruta / pantalla / acción | Archivos propios | Permisos y flujo | Contrato externo visible | Prueba |
|---|---|---|---|---|
| [ruta] | [archivos] | [roles, acción] | [ninguno o contrato] | [spec] |

## Registro único de hallazgos

Usar IDs `[SLUG]-001` y conservarlos entre auditorías. Una observación nueva sobre la misma causa raíz se agrega al ID existente, no se duplica.

| ID | P0/P1/P2/P3 | Propiedad (propio / integración / externo) | Evidencia y reproducción | Causa raíz / arreglo | Prueba | Estado |
|---|---|---|---|---|---|---|
| [id] | [prioridad] | [propietario] | [ruta, pasos, esperado/actual, confirmado/hipótesis] | [descripción] | [spec y resultado] | [estado] |

## Checklist de aceptación

- [ ] Alcance revisado y contratos externos delimitados.
- [ ] Todas las rutas y acciones propias revisadas.
- [ ] Formularios con validaciones de modelo y errores individuales por campo.
- [ ] Permisos, aislamiento organizacional, soft delete y operaciones concurrentes aplicables.
- [ ] Estados vacío, carga, error, 401/403/404/422, éxito y recuperación.
- [ ] Diseño Delta POS, desktop/móvil, teclado, foco, zoom, lector de pantalla.
- [ ] Traducciones `es` / `en` / `ko` visibles y contrastadas.
- [ ] Hallazgos P0/P1 resueltos y evidencia de pruebas.
- [ ] P2 corregidos o aceptados por propietario con motivo documentado.
- [ ] RSpec focalizado (comando, log y SHA) **ejecutado**.
- [ ] RuboCop / seguridad / I18n (comando, log y SHA) **ejecutados**.
- [ ] GitHub Actions global verde en el SHA de aceptación.
- [ ] Revisión final independiente realizada, con resultado por hallazgo.

## Historial de verificaciones

| Fecha | SHA | Tipo y comando | Resultado real | Evidencia/URL | Limitaciones |
|---|---|---|---|---|---|
| [fecha] | [sha] | [RSpec / navegador / CI] | **NO EJECUTADO / PASÓ / FALLÓ** | [enlace] | [detalle] |

## Dependencias externas y traspasos

| Contrato desde este módulo | Propietario del otro módulo | Qué se comprueba aquí | Qué NO se audita aquí | Ticket/registro |
|---|---|---|---|---|
| [relación] | [otro módulo] | [entrada y respuesta esperadas] | [implementación interna] | [enlace o pendiente] |

## Dictamen de cierre

- **Estado:** PENDIENTE DE VERIFICACIÓN.
- **P0/P1 abiertos:** [número verificado, o desconocido si no hubo ejecución].
- **P2 aceptados:** [IDs y justificación].
- **Evidencia de pruebas y UI:** [links/SHA].
- **Aprobado por / fecha:** [pendiente].
- **Motivo de bloqueo (si aplica):** [faltan pruebas/CI/browser/hallazgo].

Cambiar a `CERRADO` solo si se cumplen todas las puertas del [estándar modular](module-quality-standard.md) y la evidencia del SHA está vinculada. Al copiar a `docs/quality/modules/`, actualizar este enlace a `../module-quality-standard.md`.