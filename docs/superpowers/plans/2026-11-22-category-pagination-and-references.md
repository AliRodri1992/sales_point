# Category pagination and reference reassignment

**Goal:** Agrupar los controles de página y permitir liberar las referencias de
una categoría inactiva sin debilitar el bloqueo de baja.

**Architecture:** El footer agrupa los enlaces existentes en un nav responsive
con ventana de páginas. Una acción propia de Categorías muestra origen, recuentos
y destino activo; un objeto de formulario transfiere las referencias mediante
validaciones y una transacción. La baja sigue siendo una acción posterior explícita.

**Constraints:** Solo `feature/fixes`; misma organización; permisos de actualización
de Categorías, Productos y Promociones; conservar registros retirados, callbacks,
Turbo y es/en/ko. No tocar datos de desarrollo ni abrir otra rama.

## Tasks

- [x] Reproducir con Chrome la separación de botones; agrupar en
  `_list.html.erb` y limitar CSS a `.categories-pagination-links`; verificar
  controles de 44 px en 320/390/768/1440 px y navegación página 2.
- [x] Añadir regresiones de `/admin/categories/:id/references` y `PATCH reassign`;
  permitir destino activo distinto y propio; rechazar vacío, inactivo, retirado,
  ajeno y ausencia de permisos, sin modificar referencias ante errores.
- [x] Implementar `Categories::ReferenceTransfer#save`, con bloqueo ordenado de
  origen/destino y transacción de productos/condiciones. Conservar asociaciones
  históricas retiradas; rollback si cualquier referencia falla sus validaciones.
- [x] Integrar formulario modal con select Delta, recuentos, envío explícito y errores
  por campo; conservar filtros en HTML y Turbo; añadir traducciones equivalentes.
- [x] Validar eliminación de categoría inactiva sin uso y bloqueo con referencias;
  probar flujo completo reasignar → retirar en navegador.
- [ ] Ejecutar pruebas focalizadas, RuboCop, Brakeman, I18n y control documental;
  revisión independiente, commit/publicación sin force y consulta de CI.

**Review focus:** aislamiento organizacional; destinos alterados concurrentemente;
rollback parcial; referencias inactivas frente a retiradas; permisos de los módulos
afectados. Estos casos se incluyen en las pruebas del flujo.

**Evidencia antes de publicar:** 170 ejemplos, 0 fallos (seed 45173); RuboCop de
7 archivos sin ofensas; Brakeman sin advertencias; I18n estricto aprobado. La
revisión independiente identificó y revalidó el bloqueo FK y el envío Turbo de
la vista directa. Ver `docs/quality/modules/categories.md` para resultados y
limitaciones; la publicación y el estado de CI se informan en el chat del cambio.
