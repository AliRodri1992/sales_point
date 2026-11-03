# frozen_string_literal: true

module EmailTemplates
  class TestDelivery
    LIMIT_PER_HOUR = 3

    def self.call(template:, actor:, recipient:)
      recipient = validate_recipient!(actor, recipient)
      raise ArgumentError, 'Template not published' unless template.published_version

      template.with_lock do
        check_limit!(template, actor)
        template.audit!(action: 'test_sent', actor:)
        EmailTemplateTestMailer.sample(template.id, recipient).deliver_later
      end
    end

    def self.validate_recipient!(actor, value)
      recipient = value.to_s.strip.downcase
      raise ArgumentError, 'Invalid recipient' unless recipient.match?(URI::MailTo::EMAIL_REGEXP)
      raise Pundit::NotAuthorizedError unless actor.role?('super_admin') || recipient == actor.email.downcase

      recipient
    end

    def self.check_limit!(template, actor)
      recent = template.audits.where(action: 'test_sent', actor:)
                       .where(created_at: 1.hour.ago..).count
      raise ArgumentError, 'Test email limit reached' if recent >= LIMIT_PER_HOUR
    end
  end
end
