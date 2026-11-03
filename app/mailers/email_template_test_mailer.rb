# frozen_string_literal: true

class EmailTemplateTestMailer < ApplicationMailer
  def sample(template_id, recipient)
    template = EmailTemplate.find(template_id)
    raise ArgumentError, 'Template must be published' unless template.published_version

    variables = {
      recipient_name: 'Invitado de ejemplo', recipient_email: recipient,
      invited_name: 'Invitado de ejemplo',
      organization_name: template.organization&.name || 'Organización de ejemplo',
      activation_url: 'https://example.org/preview',
      logo_url: 'https://example.org/logo.png',
      platform_logo: 'https://example.org/logo.png',
      organization_logo: 'https://example.org/logo.png',
      support_email: 'soporte@example.org',
      support_url: 'https://example.org/support', privacy_url: 'https://example.org/privacy',
      current_year: Time.current.year, expiration_hours: 72, platform_name: 'Delta POS',
      status_label: 'Activo'
    }
    subject, html, plain = template.render_with(variables)
    mail(to: recipient, subject: "[TEST] #{subject}") do |format|
      format.html { render body: html, content_type: 'text/html' }
      format.text { render plain: }
    end
  end
end
