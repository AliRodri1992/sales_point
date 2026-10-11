# frozen_string_literal: true

module SystemRoleBreadcrumbsHelper
  def system_role_breadcrumb_items
    roles_path = { label: t('admin.breadcrumbs.roles'), path: system_roles_path }

    case params[:action]
    when 'new', 'create'
      [roles_path, { label: t('admin.system_roles.new.title') }]
    when 'edit'
      [roles_path, { label: t('admin.system_roles.edit.title') }]
    else
      [roles_path]
    end
  end
end
