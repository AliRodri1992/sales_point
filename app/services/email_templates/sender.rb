# frozen_string_literal: true

module EmailTemplates
  class Sender
    def self.call(organization: nil)
      setting = EmailSenderSetting.find_by(organization:)
      default = ENV.fetch('DELTA_POS_MAIL_FROM', 'from@example.com')
      return default unless setting&.domain_status == 'verified'

      address = setting.from_address.to_s.downcase
      domain = address.split('@').last
      return default if address.blank? || domain != setting.domain.to_s.downcase

      %("#{setting.display_name.gsub(/[\r\n"]/, '')}" <#{address}>)
    end
  end
end
