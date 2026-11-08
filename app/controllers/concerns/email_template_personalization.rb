# frozen_string_literal: true

# Safely copy published global email templates into the current tenant.
module EmailTemplatePersonalization
  def personalize
    authorize @template, :personalize?
    raise Pundit::NotAuthorizedError unless current_organization

    target, created = EmailTemplates::Personalizer.call(
      source: @template, organization: current_organization, actor: current_user
    )
    @template = target
    notify_email_template('personalized') if created
    destination = policy(target).update? ? edit_admin_email_template_path(target) : admin_email_template_path(target)
    message = created ? 'personalized_toast' : 'customization_exists'
    redirect_to destination, status: :see_other, flash: { swal_message: t("admin.email_templates.#{message}") }
  end

end
