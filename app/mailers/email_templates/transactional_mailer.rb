# frozen_string_literal: true

module EmailTemplates
  class TransactionalMailer < ApplicationMailer
    def notification(template_id, recipient, values, organization_id = nil, version_id = nil)
      template = EmailTemplate.published.find(template_id)
      version = version_id ? template.versions.find_by!(id: version_id, status: 'published') : template.published_version
      raise ArgumentError, 'Template has no published version' unless version

      if organization_id && template.organization_id && template.organization_id != organization_id
        raise ActiveRecord::RecordNotFound, 'Email template tenant mismatch'
      end

      subject, html, plain = Renderer.new(source: version, values: values.deep_symbolize_keys).render
      organization = organization_id ? Organization.find(organization_id) : template.organization
      headers = Sender.headers_for(organization:)
      mail(to: recipient, subject:, **headers) do |format|
        format.html { render body: html, content_type: 'text/html' }
        format.text { render plain: }
      end
    end
  end
end
