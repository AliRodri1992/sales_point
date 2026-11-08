# frozen_string_literal: true

module EmailTemplates
  class TransactionalMailer < ApplicationMailer
    def notification(template_id, recipient, values, organization_id = nil)
      template = EmailTemplate.published.find(template_id)
      raise ArgumentError, 'Template has no published version' unless template.published_version

      subject, html, plain = template.render_with(values.deep_symbolize_keys)
      organization = organization_id ? Organization.find(organization_id) : template.organization
      headers = Sender.headers_for(organization:)
      mail(to: recipient, subject:, **headers) do |format|
        format.html { render body: html, content_type: 'text/html' }
        format.text { render plain: }
      end
    end
  end
end
