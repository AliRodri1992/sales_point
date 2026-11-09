# frozen_string_literal: true

module EmailTemplates
  # Prevent publishing or queuing messages that would use placeholder contact
  # details. Only variables actually referenced by the selected version matter.
  class DeliveryReadiness
    CONTACT_VARIABLES = %w[support_email support_url privacy_url].freeze

    def self.missing_contacts(source:, organization:)
      return [] unless Rails.env.production?

      bodies = [source.subject, (source.preheader if source.respond_to?(:preheader)),
                source.html_body, source.text_body]
      used = bodies.flat_map { |body| body.to_s.scan(Renderer::VARIABLE_PATTERN).flatten }.uniq
      required = used & CONTACT_VARIABLES
      return [] if required.empty?

      global = EmailBrandingSetting.find_by(organization_id: nil)
      local = EmailBrandingSetting.find_by(organization:) if organization
      values = Branding.contact_values(local, global)
      required.reject { |key| configured?(key, values[key.to_sym]) }
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
