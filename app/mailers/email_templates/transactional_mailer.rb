# frozen_string_literal: true

module EmailTemplates
  class TransactionalMailer < ApplicationMailer
    def notification(template_id, recipient, values)
      template = EmailTemplate.published.find(template_id)
      raise ArgumentError, 'Template has no published version' unless template.published_version

      subject, html, plain = template.render_with(values.deep_symbolize_keys)
      mail(to: recipient, from: Sender.call(organization: template.organization), subject:) do |format|
        format.html { render body: html, content_type: 'text/html' }
        format.text { render plain: }
      end
    end
  end
end
