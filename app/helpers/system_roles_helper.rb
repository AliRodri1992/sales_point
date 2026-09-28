# frozen_string_literal: true

module SystemRolesHelper
  MODULE_ICONS = {
    'dashboard' => 'computer-desktop',
    'sales' => 'banknotes',
    'cash_register' => 'wallet',
    'caja' => 'wallet',
    'inventory' => 'circle-stack',
    'inventario' => 'circle-stack',
    'customers' => 'identification',
    'clientes' => 'identification',
    'suppliers' => 'truck',
    'proveedores' => 'truck',
    'employees' => 'user-group',
    'empleados' => 'user-group',
    'reports' => 'chart-bar',
    'reportes' => 'chart-bar',
    'products' => 'cube',
    'productos' => 'cube',
    'categories' => 'tag',
    'categorías' => 'tag',
    'branches' => 'building-office-2',
    'sucursal' => 'building-office-2',
    'sucursales' => 'building-office-2',
    'languages' => 'globe-europe-africa',
    'idiomas' => 'globe-europe-africa',
    'roles' => 'shield-check',
    'permissions' => 'key'
  }.freeze

  DEFAULT_MODULE_ICON = 'key'

  def permission_icon(permission)
    MODULE_ICONS.fetch(permission.module_name.to_s.parameterize, DEFAULT_MODULE_ICON)
  end
end
