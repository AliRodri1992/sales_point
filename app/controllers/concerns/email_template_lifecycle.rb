# frozen_string_literal: true

# Email template lifecycle actions retain version history and emit notifications.
module EmailTemplateLifecycle
  def archive
    authorize @template, :archive?
    @template.update!(status: 'archived', enabled: false)
    @template.audit!(action: 'archived', actor: current_user)
    notify_email_template('archived')
    redirect_to admin_email_templates_path,
                status: :see_other,
                flash: { swal_message: t('admin.email_templates.archived') }
  end

  def deactivate
    authorize @template, :deactivate?
    @template.update!(status: 'inactive', enabled: false, updated_by: current_user)
    @template.audit!(action: 'deactivated', actor: current_user)
    notify_email_template('deactivated')
    redirect_to admin_email_templates_path,
                status: :see_other,
                flash: { swal_message: t('admin.email_templates.deactivated_toast') }
  end

  def activate
    authorize @template, :activate?
    @template.update!(status: 'published', enabled: true, updated_by: current_user)
    @template.audit!(action: 'activated', actor: current_user)
    notify_email_template('activated')
    redirect_to admin_email_templates_path,
                status: :see_other,
                flash: { swal_message: t('admin.email_templates.activated_toast') }
  end

  def reactivate
    authorize @template, :reactivate?
    @template.update!(status: 'draft', enabled: false, updated_by: current_user)
    @template.new_draft!(actor: current_user) unless @template.versions.exists?(status: 'draft')
    @template.audit!(action: 'reactivated', actor: current_user)
    notify_email_template('reactivated')
    redirect_to edit_admin_email_template_path(@template),
                status: :see_other,
                flash: { swal_message: t('admin.email_templates.reactivated_toast') }
  end

  # Legacy DELETE stays available, but uses the canonical archive workflow.
  def destroy
    authorize @template, :destroy?
    archive
  end
end
