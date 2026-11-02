# Auditoría e implementación UI/UX — Usuarios (Delta POS)

## Problemas encontrados

- El directorio original utilizaba una tabla poco legible, acciones pequeñas,
  filtros sin jerarquía visual y una paginación que recorría todos los números.
- Los filtros y el formulario utilizaban selects nativos sin la identidad
  del sistema.
- Los roles globales podían sobrescribir indirectamente los roles por sucursal.
- Las consultas y acciones de usuarios no estaban delimitadas por la
  membresía de la organización actual.
- Las nuevas cuentas no se vinculaban a la organización administrada.
- El formulario no tenía un editor para roles de sucursal.
- La vista de detalle contenía HTML confiado manualmente para un valor vacío.
- La confirmación de borrado omitía la interpolación del nombre del usuario.
- La eliminación de cuentas multi-organización podía afectar otras entidades.

## Ajustes realizados

- Directorio responsivo con tarjetas KPI, filtros agrupados, estados, avatares,
  acciones accesibles, paginación compacta y estados vacíos diferenciados.
- Formularios de alta y edición con grupos de identidad, credenciales,
  roles globales, roles por sucursal y preferencias.
- Dropdowns de Delta POS sin controles tipo radio; validación debajo de
  cada campo utilizando errores de modelo Rails.
- Perfil de usuario con resumen, seguridad, roles globales y roles por sucursal.
- Consultas acotadas por membresía activa de la organización; roles guardados
  en transacción sin destruir asignaciones ajenas.
- Selección y validación del acceso por sucursal sin habilitar sucursales
  inactivas o de otras organizaciones.
- Prevención de borrado de la propia cuenta o de cuentas compartidas.
- Traducciones para español, inglés y coreano.
- Pruebas de request para límites de organización y roles; pruebas de
  navegador para listado móvil, editor de roles y validaciones.

## Alcance visual y límites

La revisión se hizo a nivel de código y comportamiento automatizado.
La captura visual real de localhost en macOS no es accesible desde este chat;
se requiere una sesión de navegador local autorizada para un pase adicional
de inspección visual en dispositivos reales.
