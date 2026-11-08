# frozen_string_literal: true

module Admin
  # Keeps creation, activity notifications and the existing CRUD controller separate.
  module EmailTemplateActivity
    private

    def save_new_template
      if current_organization.nil? && params[:global] != '1'
        @template.errors.add(:organization, t('admin.email_templates.organization_required'))
        return render :new, status: :unprocessable_content
      end

      saved = EmailTemplate.transaction do
        next false unless @template.save

        draft = @template.new_draft!(actor: current_user)
        @template.audit!(action: 'created', actor: current_user, version: draft)
        true
      end
      return render :new, status: :unprocessable_content unless saved

      finish_template_creation
    end

    def finish_template_creation
      notify_email_template('created')
      destination = if policy(@template).update?
                      edit_admin_email_template_path(@template)
                    else
                      admin_email_template_path(@template)
                    end
      redirect_to destination, flash: { swal_message: t('admin.email_templates.created_toast') }
    end

    def notify_email_template(action)
      EmailTemplateNotification.with(action:, record: @template, user: current_user)
                               .deliver(current_user, enqueue_job: false)
      current_user.broadcast_notifications_refresh
    rescue StandardError => error
      Rails.logger.error("Email notification delivery failed: #{error.class}")
    end
  end
end
