# frozen_string_literal: true

# Email template lifecycle actions retain version history and emit notifications.
module EmailTemplateLifecycle
  def archive
    authorize @template, :archive?
    archived = @template.with_lock do
      next false if @template.status == 'archived'

      @template.update!(status: 'archived', enabled: false, updated_by: current_user)
      @template.audit!(action: 'archived', actor: current_user)
      true
    end
    notify_email_template('archived') if archived
    redirect_to admin_email_templates_path,
                status: :see_other,
                flash: { swal_message: t('admin.email_templates.archived') }
  end

  def deactivate
    authorize @template, :deactivate?
    EmailTemplate.transaction do
      @template.update!(status: 'inactive', enabled: false, updated_by: current_user)
      @template.audit!(action: 'deactivated', actor: current_user)
    end
    notify_email_template('deactivated')
    redirect_to admin_email_templates_path,
                status: :see_other,
                flash: { swal_message: t('admin.email_templates.deactivated_toast') }
  end

  def activate
    authorize @template, :activate?
    EmailTemplate.transaction do
      @template.update!(status: 'published', enabled: true, updated_by: current_user)
      @template.audit!(action: 'activated', actor: current_user)
    end
    notify_email_template('activated')
    redirect_to admin_email_templates_path,
                status: :see_other,
                flash: { swal_message: t('admin.email_templates.activated_toast') }
  end

  def reactivate
    authorize @template, :reactivate?
    EmailTemplate.transaction do
      @template.update!(status: 'draft', enabled: false, updated_by: current_user)
      @template.new_draft!(actor: current_user)
      @template.audit!(action: 'reactivated', actor: current_user)
    end
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
