# frozen_string_literal: true

module EmailTemplateBreadcrumbsHelper
  def email_template_breadcrumb_items
    base = email_template_section_breadcrumb
    template = controller.view_assigns['template']

    case params[:action]
    when 'index'
      [base.except(:path)]
    when 'new', 'create'
      [base, { label: t('admin.email_templates.new') }]
    when 'edit', 'update_draft', 'compare'
      [base, template_breadcrumb(template), { label: editor_breadcrumb_label }]
    else
      [base, { label: template&.name || t('admin.email_templates.view') }]
    end
  end

  def email_branding_breadcrumb_items
    [email_template_section_breadcrumb,
     { label: t('admin.breadcrumbs.controllers.email_branding_settings') }]
  end

  def email_sender_breadcrumb_items
    [email_template_section_breadcrumb,
     { label: t('admin.breadcrumbs.controllers.email_sender_settings') }]
  end

  private

  def email_template_section_breadcrumb
    { label: t('admin.breadcrumbs.controllers.email_templates'), path: admin_email_templates_path }
  end

  def editor_breadcrumb_label
    return t('admin.email_templates.compare') if params[:action] == 'compare'

    t('admin.email_templates.edit')
  end

  def template_breadcrumb(template)
    {
      label: template&.name || t('admin.email_templates.view'),
      path: template && admin_email_template_path(template)
    }.compact
  end
end
