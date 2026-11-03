# frozen_string_literal: true

class UserStatusMailer < ApplicationMailer
  def changed(event_id)
    @event = UserStatusEvent.includes(:organization).find(event_id)
    @user = User.with_deleted.find(@event.user_id)
    subject, html, plain = status_template.render_with(template_values)
    mail(to: @user.email, subject:) do |format|
      format.html { render body: html, content_type: 'text/html' }
      format.text { render plain: }
    end
  end

  private

  def status_template
    EmailTemplate.ensure_status_template!
    EmailTemplate.find_by(key: 'user_status_changed', locale: locale, enabled: true) ||
      EmailTemplate.find_by!(key: 'user_status_changed', locale: 'es', enabled: true)
  end

  def locale
    code = @user.language&.code.to_s.downcase
    I18n.available_locales.include?(code.to_sym) ? code : 'es'
  end

  def template_values
    {
      recipient_name: @user.display_name,
      organization_name: @event.organization.name,
      status_label: I18n.t("admin.users.statuses.#{@event.to_status}", locale: locale),
      logo_url: ActionController::Base.helpers.image_url(
        'delta-pos-logo.svg', host: default_url_options[:host]
      )
    }
  end
end
