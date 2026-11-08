# frozen_string_literal: true

module EmailTemplateBreadcrumbsHelper
  def email_template_breadcrumb_items
    base = { label: t('admin.breadcrumbs.controllers.email_templates'), path: admin_email_templates_path }
    template = controller.view_assigns['template']

    case params[:action]
    when 'index'
      [base.except(:path)]
    when 'new', 'create'
      [base, { label: t('admin.email_templates.new') }]
    when 'show'
      [base, { label: template&.name || t('admin.email_templates.view') }]
    when 'edit', 'update_draft'
      [base, template_breadcrumb(template), { label: t('admin.email_templates.edit') }]
    when 'compare'
      [base, template_breadcrumb(template), { label: t('admin.email_templates.compare') }]
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

  def template_breadcrumb(template)
    {
      label: template&.name || t('admin.email_templates.view'),
      path: template && admin_email_template_path(template)
    }.compact
  end
end
