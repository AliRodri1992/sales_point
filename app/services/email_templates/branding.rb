# frozen_string_literal: true

module EmailTemplates
  class Branding
    PLATFORM_LOGO_WEB = 'delta-pos-email-logo.svg'
    PLATFORM_LOGO_EMAIL = 'delta-pos-email-logo.png'

    def self.values(organization: nil)
      global = EmailBrandingSetting.find_by(organization_id: nil)
      local = EmailBrandingSetting.find_by(organization:) if organization
      {
        platform_name: global&.display_name.presence || 'Delta POS',
        organization_name: organization_name(local, organization),
        support_email: setting_value(local, global, :support_email, ENV.fetch('DELTA_POS_SUPPORT_EMAIL', 'support@example.org')),
        support_url: setting_value(local, global, :support_url, ENV.fetch('DELTA_POS_SUPPORT_URL', 'https://example.org/support')),
        privacy_url: setting_value(local, global, :privacy_url, ENV.fetch('DELTA_POS_PRIVACY_URL', 'https://example.org/privacy')),
        **color_and_footer_values(local, global),
        platform_logo: platform_logo_url,
        organization_logo: asset_logo(local&.logo&.attached? ? local : global),
        logo_url: platform_logo_url
      }
    end

    def self.color_and_footer_values(local, global)
      {
        primary_color: setting_value(local, global, :primary_color, '#064e3b'),
        secondary_color: setting_value(local, global, :secondary_color, '#047857'),
        button_color: setting_value(local, global, :button_color, '#047857'),
        footer_text: setting_value(local, global, :footer_text, '')
      }
    end

    def self.asset_logo(setting)
      return platform_logo_url unless setting&.logo&.attached?

      mailer_options = Rails.application.config.action_mailer.default_url_options || {}
      Rails.application.routes.url_helpers.rails_blob_url(
        setting.logo, host: configured_host, port: mailer_options[:port],
                      protocol: Rails.env.development? ? 'http' : 'https'
      )
    end

    def self.platform_logo_url
      asset_host = Rails.application.config.action_mailer.asset_host if Rails.env.development?
      asset_host ||= "https://#{configured_host}"
      ActionController::Base.helpers.image_url(PLATFORM_LOGO_EMAIL, host: asset_host)
    end

    def self.configured_host
      ENV['DELTA_POS_PUBLIC_HOST'].presence ||
        Rails.application.config.action_mailer.default_url_options&.dig(:host) ||
        'www.example.com'
    end

    def self.organization_name(local, organization)
      local&.display_name.presence || organization&.name || 'Delta POS'
    end

    def self.setting_value(local, global, key, default)
      local&.public_send(key).presence || global&.public_send(key).presence || default
    end
  end
end
