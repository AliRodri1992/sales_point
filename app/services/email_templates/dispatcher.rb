# frozen_string_literal: true

module EmailTemplates
  class Dispatcher
    def self.call(key:, locale:, recipient:, values:, organization: nil)
      template = EmailTemplate.resolve(key:, locale:, organization:)
      raise ActiveRecord::RecordNotFound, 'Published template not found' unless template&.published_version

      raise ArgumentError, 'Invalid recipient' unless recipient.to_s.match?(URI::MailTo::EMAIL_REGEXP)

      branding = EmailTemplates::Branding.values(organization: template.organization)
      ciphertext = EncryptedPayload.encrypt(
        template_id: template.id, recipient:, values: values.symbolize_keys.merge(branding)
      )
      EmailTemplates::DeliveryJob.perform_later(ciphertext)
    end
  end
end
