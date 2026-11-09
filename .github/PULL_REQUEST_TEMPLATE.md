## Alcance del cambio

- **Módulo / ruta(s) propias:** 
- **Registro de calidad modular:** enlace a `docs/quality/modules/<slug>.md` (o «No aplica» con justificación si no es cambio modular).
- **Hallazgos que resuelve:** IDs permanentes (p. ej., `BR-001`) y causa raíz.
- **Incluido / excluido:** acciones propias y frontera con módulos vecinos.
- **Contratos de integración afectados:** descripción mínima, o «Ninguno»; no auditar/reformular internamente los módulos vecinos sin motivo.

## Implementación y pruebas de regresión

- [ ] Los cambios están limitados al alcance declarado; cualquier código externo cambiado tiene justificación y prueba de contrato.
- [ ] Las correcciones atacan la causa raíz; los hallazgos ya existentes conservan su ID y evidencia.
- [ ] Las reglas de modelo/servidor, autorización Pundit, aislamiento organizacional y concurrencia aplicables tienen pruebas negativas.
- [ ] Los formularios afectados tienen errores individuales **debajo de cada campo** y obligatorios señalados con asterisco rojo, sin `required` HTML5 como sustituto de la validación del modelo.
- [ ] Se revisó UX, responsive, estados carga/vacío/error/422, navegación por teclado, foco y traducciones `es/en/ko`, o se documenta lo pendiente.
- [ ] Se añadieron o actualizaron las pruebas de regresión necesarias.

## Evidencia REAL de calidad

> Dejar una comprobación como **NO EJECUTADA** si no hay salida real; no marcarla aprobada por haber hecho push.

| Comprobación | Comando / job | Resultado (PASÓ / FALLÓ / NO EJECUTADO) | SHA y enlace/log |
|---|---|---|---|
| RSpec focalizado | | | |
| RSpec completo | | | |
| RuboCop | | | |
| Security scans | | | |
| I18n y YAML | | | |
| Browser móvil/escritorio (si aplica) | | | |
| CI completo | | | |

## Cierre

- [ ] No quedan hallazgos **P0/P1** abiertos en el módulo afectado.
- [ ] Los **P2** están resueltos o aceptados formalmente con responsable y explicación.
- [ ] CI completo pasó para el **SHA exacto** candidato a integración.
- [ ] El registro de calidad incluye evidencia, riesgos residuales y revisión final independiente.
- [ ] **No fusionar** si una condición requerida está pendiente, fallida o no ejecutada.

**Estado de entrega:** IMPLEMENTADO SIN VERIFICAR / VERIFICADO / CERRADO / BLOQUEADO  
**SHA candidato:**  
**Revisor de cierre y fecha:**  

Guía: [Estándar de calidad modular](../docs/quality/module-quality-standard.md). La plantilla documenta decisiones; la protección de rama con checks requeridos es la que impide técnicamente merges con CI rojo.