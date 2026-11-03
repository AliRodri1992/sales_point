# frozen_string_literal: true

class UserStatusMailer < ApplicationMailer
  def changed(event_id)
    event = UserStatusEvent.includes(:organization).find(event_id)
    user = User.with_deleted.find(event.user_id)
    locale = user.language&.code.to_s.downcase
    locale = 'es' unless I18n.available_locales.include?(locale.to_sym)

    EmailTemplate.ensure_status_template!
    template = EmailTemplate.find_by(key: 'user_status_changed', locale:, enabled: true) ||
               EmailTemplate.find_by!(key: 'user_status_changed', locale: 'es', enabled: true)
    subject, html, plain = template.render_with(template_values(event, user, locale))
    mail(to: user.email, subject:) do |format|
      format.html { render body: html, content_type: 'text/html' }
      format.text { render plain: }
    end
  end

  private

  def template_values(event, user, locale)
    {
      recipient_name: user.display_name,
      organization_name: event.organization.name,
      status_label: I18n.t("admin.users.statuses.#{event.to_status}", locale:),
      logo_url: ActionController::Base.helpers.image_url(
        'delta-pos-logo.svg', host: default_url_options[:host]
      )
    }
  end
end
