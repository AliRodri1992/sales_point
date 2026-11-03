# frozen_string_literal: true

module EmailTemplates
  class Sender
    def self.call(organization: nil)
      headers_for(organization:)[:from] || ENV.fetch('DELTA_POS_MAIL_FROM', 'from@example.com')
    end

    def self.headers_for(organization: nil)
      local = EmailSenderSetting.find_by(organization:) if organization
      setting = verified?(local) ? local : EmailSenderSetting.find_by(organization_id: nil)
      return {} unless verified?(setting)

      name = setting.display_name.to_s.gsub(/[\r\n"]/, '')
      headers = { from: %("#{name}" <#{setting.from_address.downcase}>) }
      headers[:reply_to] = setting.reply_to if setting.reply_to.present?
      headers
    end

    def self.verified?(setting)
      setting&.domain_status == 'verified' &&
        setting.from_address.present? &&
        setting.domain.present? &&
        setting.from_address.split('@').last&.casecmp?(setting.domain)
    end
  end
end
