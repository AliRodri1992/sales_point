# frozen_string_literal: true

# Email template lifecycle actions retain version history and emit notifications.
module EmailTemplateLifecycle
  def archive
    authorize @template, :archive?
    @template.update!(status: 'archived', enabled: false)
    @template.audit!(action: 'archived', actor: current_user)
    notify_email_template('archived')
    redirect_to admin_email_templates_path,
                flash: { swal_message: t('admin.email_templates.archived') }
  end

  def destroy
    authorize @template, :destroy?
    @template.update!(status: 'archived', enabled: false, updated_by: current_user)
    @template.audit!(action: 'archived', actor: current_user)
    notify_email_template('removed')
    redirect_to admin_email_templates_path, status: :see_other,
                flash: { swal_message: t('admin.email_templates.removed') }
  end
end
