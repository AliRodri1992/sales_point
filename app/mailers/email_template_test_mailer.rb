# frozen_string_literal: true

class EmailTemplateTestMailer < ApplicationMailer
  def sample(template_id, recipient, version_id = nil)
    template = EmailTemplate.find(template_id)
    raise ArgumentError, 'Template must be published' unless testable?(template)

    version = version_id ? template.versions.find_by!(id: version_id, status: 'published') : template.published_version
    subject, html, plain = sample_content(template, recipient, version)
    headers = EmailTemplates::Sender.headers_for(organization: template.organization)
    mail(to: recipient, subject: "[TEST] #{subject}", **headers) do |format|
      format.html { render body: html, content_type: 'text/html' }
      format.text { render plain: }
    end
  end

  private

  def testable?(template)
    template.status == 'published' && template.enabled? && template.published_version.present?
  end

  def sample_content(template, recipient, version)
    variables = EmailTemplates::SampleData.call(template)
    variables[:recipient_email] = recipient
    EmailTemplates::Renderer.new(source: version, values: variables).render
  end
end
