# frozen_string_literal: true

module EmailTemplates
  class Branding
    def self.values(organization: nil)
      global = EmailBrandingSetting.find_by(organization_id: nil)
      local = EmailBrandingSetting.find_by(organization:) if organization
      {
        platform_name: global&.display_name.presence || 'Delta POS',
        organization_name: organization_name(local, organization),
        support_email: setting_value(local, global, :support_email, 'support@example.org'),
        support_url: setting_value(local, global, :support_url, 'https://example.org/support'),
        privacy_url: setting_value(local, global, :privacy_url, 'https://example.org/privacy'),
        platform_logo: asset_logo(global),
        organization_logo: asset_logo(local),
        logo_url: asset_logo(global)
      }
    end

    def self.asset_logo(setting)
      host = ENV['DELTA_POS_PUBLIC_HOST'].presence ||
             Rails.application.config.action_mailer.default_url_options&.dig(:host) ||
             'www.example.com'
      base_url = "https://#{host}"
      if setting&.logo&.attached?
        return Rails.application.routes.url_helpers.rails_blob_url(setting.logo, host:, protocol: 'https')
      end

      ActionController::Base.helpers.image_url('delta-pos-logo.svg', host: base_url)
    end

    def self.organization_name(local, organization)
      local&.display_name.presence || organization&.name || 'Delta POS'
    end

    def self.setting_value(local, global, key, default)
      local&.public_send(key).presence || global&.public_send(key).presence || default
    end
  end
end
