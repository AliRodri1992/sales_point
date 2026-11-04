# frozen_string_literal: true

module RolePermissionCatalogHelper
  PERMISSION_MODULES = %w[
    dashboard sales cash_register inventory customers suppliers employees reports products
    categories branches languages roles users purchases accounts_payable
  ].freeze
  PERMISSION_ACTIONS = %w[
    access index list show view create update edit destroy delete archive restore manage
    approve receive returns pay reveal review set_primary geocode prefer activate suspend
    reactivate block unblock invite resend_invitation publish preview send_test versions
  ].freeze

  def permission_module_key(permission)
    prefix = permission.code.split('.').first
    return prefix if PERMISSION_MODULES.include?(prefix)
    return 'communication' if prefix.start_with?('email_')

    permission.module_name
  end

  def permission_module_label(key)
    t("admin.system_roles.catalog.modules.#{key}", default: key.to_s.humanize)
  end

  def permission_resource_key(permission)
    permission.code.split('.')[0...-1].join('_')
  end

  def permission_resource_label(permission)
    key = permission_resource_key(permission)
    t("admin.system_roles.catalog.resources.#{key}", default: permission_module_label(key))
  end

  def permission_action_label(permission)
    action = permission.code.split('.').last
    return permission_name(permission) unless PERMISSION_ACTIONS.include?(action)

    t("admin.system_roles.catalog.actions.#{action}")
  end

  def grouped_role_permissions(permissions)
    permissions.group_by { |permission| permission_module_key(permission) }
               .sort_by { |key, _| permission_module_label(key).downcase }
  end

  def sorted_resource_permissions(permissions)
    permissions.sort_by do |permission|
      [PERMISSION_ACTIONS.index(permission.code.split('.').last) || PERMISSION_ACTIONS.length, permission.code]
    end
  end
end
