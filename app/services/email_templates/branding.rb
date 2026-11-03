# frozen_string_literal: true

module EmailTemplates
  class Branding
    def self.values(organization: nil)
      global = EmailBrandingSetting.find_by(organization_id: nil)
      local = organization && EmailBrandingSetting.find_by(organization:)
      {
        platform_name: global&.display_name.presence || 'Delta POS',
        organization_name: local&.display_name.presence || organization&.name || 'Delta POS',
        support_email: local&.support_email.presence || global&.support_email || 'support@example.org',
        support_url: local&.support_url.presence || global&.support_url || 'https://example.org/support',
        privacy_url: local&.privacy_url.presence || global&.privacy_url || 'https://example.org/privacy'
      }
    end
  end
end
