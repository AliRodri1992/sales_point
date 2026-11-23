# Fidelidad visual del editor de permisos

Fuente aprobada: `delta-pos-administrar-permisos.zip`, última versión del 22 de noviembre. Alcance: `/system_roles/:id` en los modos Administrar permisos y Ver permisos. La ficha de rol, pestañas, matriz de recursos y acciones, filtros y pie se integran en una superficie de lectura. Se conserva el catálogo completo, no las 42 entradas de demostración.

## Enfoque elegido

Adaptar las vistas ERB y Stimulus actuales, reutilizando sus asociaciones, campos y controles accesibles. Una copia estática del JS del ZIP perdería las validaciones, y un nuevo editor paralelo duplicaría el contrato. Mantener las vistas de datos del rol y ciclo de vida como secciones secundarias, sin cambiar rutas ni autorización.

## Requisitos

- Encabezado, breadcrumb, identidad del rol, alcance, usuarios de la organización y última actualización real; pestañas de permisos/historial autorizado.
- Matriz responsive con columnas por acción, contador por recurso, iconos y descripciones de grupo, acciones especiales independientes y filtros sobre el catálogo completo. No inventar permisos cuando la acción no existe.
- Switches reales, selección masiva visible, dependencias actuales, búsqueda y leyenda; estados vacío, protegido, compartido y archivado.
- Resumen de altas/bajas, revisión con conteos y advertencia de impacto, confirmación para descartar o volver, preservación de datos ante 422.
- Pundit y aislamiento organizacional sin relajación, datos reales en servidor, auditoría, locales es/en/ko, SVG inline propios, tokens Delta Emerald. No incorporar CDN ni nuevos paquetes.
- Verificar a 320/390/768/1440 px, teclado, regresiones y CI en feature/fixes. No introducir otra rama remota.
