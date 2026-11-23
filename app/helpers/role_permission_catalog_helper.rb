# frozen_string_literal: true

module RolePermissionCatalogHelper
  PERMISSION_MODULES = %w[
    dashboard sales cash_register inventory customers suppliers employees reports products
    categories branches languages roles users purchases accounts_payable price_lists promotions
  ].freeze
  PERMISSION_ACTIONS = %w[
    access index list show view create update edit destroy delete archive restore manage
    approve receive returns pay reveal review set_primary geocode prefer activate suspend
    reactivate block unblock invite resend_invitation publish preview send_test versions
    pause resume duplicate history view_margin authorize_below_cost
  ].freeze
  MATRIX_ACTIONS = {
    'access' => %w[access], 'index' => %w[index list], 'show' => %w[show view],
    'create' => %w[create], 'update' => %w[update edit], 'destroy' => %w[destroy delete]
  }.freeze
  WORKSPACE_ICONS = {
    'dashboard' => 'computer-desktop', 'sales' => 'banknotes', 'cash_register' => 'wallet', 'inventory' => 'cube',
    'customers' => 'user-group', 'suppliers' => 'truck', 'employees' => 'user-group', 'reports' => 'chart-bar',
    'products' => 'cube', 'categories' => 'tag', 'units_of_measure' => 'cube', 'branches' => 'building-office-2',
    'languages' => 'language', 'roles' => 'shield-check', 'users' => 'user-group', 'purchases' => 'banknotes',
    'accounts_payable' => 'banknotes', 'price_lists' => 'tag', 'promotions' => 'tag',
    'communication' => 'envelope'
  }.freeze

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

  def matrix_resource_permissions(permissions)
    MATRIX_ACTIONS.transform_values do |aliases|
      aliases.filter_map { |action| permissions.find { |permission| permission.code.split('.').last == action } }.first
    end
  end

  def permission_workspace_icon(module_key)
    WORKSPACE_ICONS.fetch(module_key, 'key')
  end

  def role_workspace_user_count(role)
    return 0 unless current_organization

    members = current_organization.organization_memberships.where(deleted_at: nil).select(:user_id)
    assignments = role.user_roles.where(organization: current_organization, deleted_at: nil, user_id: members)
    assignments.distinct.count(:user_id)
  end

  def role_workspace_updated_at(role)
    role_policy = policy(role)
    return role.updated_at unless role_policy.audit_history? || role_policy.update_permissions?

    [role.updated_at, role.permission_audit_events.maximum(:created_at)].compact.max
  end
end
