# frozen_string_literal: true

module Admin
  # Keeps creation, activity notifications and the existing CRUD controller separate.
  module EmailTemplateActivity
    private

    def save_new_template
      if current_organization.nil? && params[:global] != '1'
        @template.errors.add(:base, t('admin.email_templates.organization_required'))
        return render :new, status: :unprocessable_content
      end

      if @template.save
        draft = @template.new_draft!(actor: current_user)
        @template.audit!(action: 'created', actor: current_user, version: draft)
        notify_email_template('created')
        destination = policy(@template).update? ? edit_admin_email_template_path(@template) :
                      admin_email_template_path(@template)
        redirect_to destination, flash: { swal_message: t('admin.email_templates.created_toast') }
      else
        render :new, status: :unprocessable_content
      end
    end

    def notify_email_template(action)
      EmailTemplateNotification.with(action:, record: @template, user: current_user)
                               .deliver(current_user, enqueue_job: false)
      current_user.broadcast_notifications_refresh
    end
  end
end
