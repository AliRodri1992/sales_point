# frozen_string_literal: true

module EmailTemplates
  class Dispatcher
    def self.call(key:, recipient:, values:, organization: nil, locale: nil)
      locale ||= default_locale(organization)
      template = EmailTemplate.resolve(key:, locale:, organization:)
      raise ActiveRecord::RecordNotFound, 'Published template not found' unless template&.published_version

      raise ArgumentError, 'Invalid recipient' unless recipient.to_s.match?(URI::MailTo::EMAIL_REGEXP)

      delivery_organization = organization || template.organization
      branding = EmailTemplates::Branding.values(organization: delivery_organization)
      sender_headers = EmailTemplates::Sender.headers_for(organization: delivery_organization)
      ciphertext = EncryptedPayload.encrypt(
        template_id: template.id, version_id: template.published_version_id,
        recipient:, organization_id: organization&.id,
        sender_headers:, values: values.symbolize_keys.merge(branding)
      )
      EmailTemplates::DeliveryJob.perform_later(ciphertext)
    end

    def self.default_locale(organization)
      setting = EmailSenderSetting.find_by(organization:) if organization
      setting&.default_locale || EmailSenderSetting.find_by(organization_id: nil)&.default_locale || 'es'
    end
  end
end
