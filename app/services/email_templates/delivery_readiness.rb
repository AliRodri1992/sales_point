# frozen_string_literal: true

module EmailTemplates
  # Prevent publishing or queuing messages that would use placeholder contact
  # details. Only variables actually referenced by the selected version matter.
  class DeliveryReadiness < ActiveModel::Validator
    CONTACT_VARIABLES = %w[support_email support_url privacy_url].freeze

    def validate(version)
      missing = self.class.missing_contacts(source: version, organization: version.email_template.organization)
      return if missing.empty?

      version.errors.add(:allowed_variables, I18n.t('admin.email_templates.delivery_contacts_required',
                                                     variables: missing.join(', ')))
    end

    def self.missing_contacts(source:, organization:)
      return [] unless Rails.env.production?

      required = required_contacts(source)
      return [] if required.empty?

      values = contact_values(organization)
      required.reject { |key| configured?(key, values[key.to_sym]) }
    end

    def self.required_contacts(source)
      fields = [source.subject, (source.preheader if source.respond_to?(:preheader)),
                source.html_body, source.text_body]
      fields.flat_map { |value| value.to_s.scan(Renderer::VARIABLE_PATTERN).flatten }.uniq & CONTACT_VARIABLES
    end

    def self.contact_values(organization)
      global = EmailBrandingSetting.find_by(organization_id: nil)
      local = EmailBrandingSetting.find_by(organization:) if organization
      Branding.contact_values(local, global)
    end

    def self.configured?(key, value)
      if key == 'support_email'
        return false unless value.to_s.match?(URI::MailTo::EMAIL_REGEXP)

        host = value.to_s.split('@', 2).last
      else
        url = URI.parse(value.to_s)
        return false unless url.is_a?(URI::HTTPS) && url.host.present? && url.userinfo.nil?

        host = url.host
      end

      !Branding.placeholder_host?(host)
    rescue URI::InvalidURIError
      false
    end
  end
end
