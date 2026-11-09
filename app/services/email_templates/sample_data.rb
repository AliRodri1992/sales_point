# frozen_string_literal: true

module EmailTemplates
  # Fake personal data with real configured branding for safe admin previews.
  class SampleData
    LOCALIZED = {
      'es' => { name: 'Usuario de ejemplo', organization: 'Mi organización', status: 'Activo' },
      'en' => { name: 'Sample user', organization: 'My organization', status: 'Active' },
      'ko' => { name: '예시 사용자', organization: '예시 조직', status: '활성' }
    }.freeze

    def self.call(template)
      sample = LOCALIZED.fetch(template.locale.to_s, LOCALIZED.fetch('es'))
      EmailTemplates::Branding.values(organization: template.organization).merge(
        name: sample.fetch(:name),
        recipient_name: sample.fetch(:name),
        recipient_email: 'prueba@example.org',
        invited_name: sample.fetch(:name),
        organization_name: template.organization&.name || sample.fetch(:organization),
        activation_url: 'https://example.org/activation-demo',
        recovery_url: 'https://example.org/recovery-demo',
        current_year: Time.current.year, expiration_hours: 72,
        status_label: sample.fetch(:status)
      )
    end
  end
end
