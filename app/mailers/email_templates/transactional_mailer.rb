# frozen_string_literal: true

module EmailTemplates
  class TransactionalMailer < ApplicationMailer
    def notification(template_id, recipient, values, organization_id = nil, version_id = nil, sender_snapshot = nil)
      template = EmailTemplate.published.find(template_id)
      source = version_for(template, version_id)
      headers = sender_headers(template, organization_id, sender_snapshot)
      subject, html, plain = Renderer.new(source:, values: values.deep_symbolize_keys).render

      mail(to: recipient, subject:, **headers) do |format|
        format.html { render body: html, content_type: 'text/html' }
        format.text { render plain: }
      end
    end

    private

    def version_for(template, version_id)
      version = if version_id
                  template.versions.find_by!(id: version_id, status: 'published')
                else
                  template.published_version
                end
      raise ArgumentError, 'Template has no published version' unless version

      version
    end

    def sender_headers(template, organization_id, sender_snapshot)
      if organization_id && template.organization_id && template.organization_id != organization_id
        raise ActiveRecord::RecordNotFound, 'Email template tenant mismatch'
      end

      return sender_snapshot.symbolize_keys.slice(:from, :reply_to) if sender_snapshot

      organization = organization_id ? Organization.find(organization_id) : template.organization
      Sender.headers_for(organization:)
    end
  end
end
