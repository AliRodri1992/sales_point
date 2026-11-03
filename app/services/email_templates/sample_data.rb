# frozen_string_literal: true

module EmailTemplates
  class SampleData
    def self.call(template)
      EmailTemplates::Branding.values(organization: template.organization).merge(
        recipient_name: 'Usuario de ejemplo',
        recipient_email: 'prueba@example.org',
        invited_name: 'Usuario de ejemplo',
        organization_name: template.organization&.name || 'Mi organización',
        organization_logo: 'https://example.org/organization.png',
        platform_logo: 'https://example.org/delta.png',
        platform_name: 'Delta POS', logo_url: 'https://example.org/delta.png',
        activation_url: 'https://example.org/activation-demo',
        support_email: 'support@example.org',
        support_url: 'https://example.org/support', privacy_url: 'https://example.org/privacy',
        current_year: Time.current.year, expiration_hours: 72, status_label: 'Activo'
      )
    end
  end
end
