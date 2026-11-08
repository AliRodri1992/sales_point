# frozen_string_literal: true

module EmailTemplates
  class TestDelivery
    LIMIT_PER_HOUR = 3

    def self.call(template:, actor:, recipient:)
      recipient = validate_recipient!(actor, recipient)
      available = template.status == 'published' && template.enabled? && template.published_version.present?
      raise ArgumentError, 'Template not published' unless available

      template.with_lock do
        check_limit!(template, actor)
        job = EmailTemplates::TestDeliveryJob.perform_later(template.id, actor.id, recipient)
        raise 'Unable to enqueue test email' unless job

        template.audit!(action: 'test_queued', actor:)
      end
    end

    def self.validate_recipient!(actor, value)
      recipient = value.to_s.strip.downcase
      raise ArgumentError, 'Invalid recipient' unless recipient.match?(URI::MailTo::EMAIL_REGEXP)
      raise Pundit::NotAuthorizedError unless actor.role?('super_admin') || recipient == actor.email.downcase

      recipient
    end

    def self.check_limit!(template, actor)
      recent = template.audits.where(action: 'test_queued', actor:)
                       .where(created_at: 1.hour.ago..).count
      raise ArgumentError, 'Test email limit reached' if recent >= LIMIT_PER_HOUR
    end
  end
end
