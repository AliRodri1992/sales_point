# frozen_string_literal: true

class EmailTemplateTestMailer < ApplicationMailer
  def sample(template_id, recipient)
    template = EmailTemplate.find(template_id)
    raise ArgumentError, 'Template must be published' unless template.published_version

    variables = EmailTemplates::SampleData.call(template)
    variables[:recipient_email] = recipient
    subject, html, plain = template.render_with(variables)
    headers = EmailTemplates::Sender.headers_for(organization: template.organization)
    mail(to: recipient, subject: "[TEST] #{subject}", **headers) do |format|
      format.html { render body: html, content_type: 'text/html' }
      format.text { render plain: }
    end
  end
end
