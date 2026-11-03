# frozen_string_literal: true

class UserStatusMailer < ApplicationMailer
  def changed(event_id)
    @event = UserStatusEvent.includes(:organization).find(event_id)
    @user = User.with_deleted.find(@event.user_id)
    subject, html, plain = status_template.render_with(template_values)
    headers = EmailTemplates::Sender.headers_for(organization: @event.organization)
    mail(to: @user.email, subject:, **headers) do |format|
      format.html { render body: html, content_type: 'text/html' }
      format.text { render plain: }
    end
  end

  private

  def status_template
    EmailTemplate.ensure_status_template!
    EmailTemplate.resolve(key: 'user_status_changed', locale:, organization: @event.organization) ||
      EmailTemplate.global.find_by!(key: 'user_status_changed', locale: 'es', enabled: true)
  end

  def locale
    code = @user.language&.code.to_s.downcase
    I18n.available_locales.include?(code.to_sym) ? code : 'es'
  end

  def template_values
    EmailTemplates::Branding.values(organization: @event.organization).merge(
      recipient_name: @user.display_name,
      recipient_email: @user.email,
      organization_name: @event.organization.name,
      status_label: I18n.t("admin.users.statuses.#{@event.to_status}", locale:)
    )
  end
end
