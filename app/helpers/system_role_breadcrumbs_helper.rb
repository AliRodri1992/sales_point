# frozen_string_literal: true

module SystemRoleBreadcrumbsHelper
  def system_role_breadcrumb_items
    roles_path = { label: t('admin.breadcrumbs.roles'), path: system_roles_path }

    case params[:action]
    when 'new', 'create'
      [roles_path, { label: t('admin.system_roles.new.title') }]
    when 'show', 'edit', 'update', 'update_permissions', 'status_review', 'change_status'
      label = content_for(:system_role_breadcrumb_label).presence || t('admin.system_roles.index.title')
      [roles_path, { label: }]
    else
      [roles_path]
    end
  end
end
