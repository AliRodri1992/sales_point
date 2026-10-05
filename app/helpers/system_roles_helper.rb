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

  def system_role_name(system_role)
    translate_system_role(system_role, :name)
  end

  def system_role_description(system_role)
    translate_system_role(system_role, :description)
  end

  def permission_name(permission)
    translate_permission(permission, :name)
  end

  def permission_description(permission)
    translate_permission(permission, :description)
  end

  private

  def translate_system_role(system_role, attribute)
    key = system_role.code.to_s.parameterize(separator: '_')
    t("admin.system_roles.roles.#{key}.#{attribute}", default: system_role.public_send(attribute))
  end

  def translate_permission(permission, attribute)
    key = permission.code.to_s.parameterize(separator: '_')
    t("admin.system_roles.permissions.#{key}.#{attribute}", default: permission.public_send(attribute))
  end
end
