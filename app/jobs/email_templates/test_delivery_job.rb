# frozen_string_literal: true

module EmailTemplates
  # Record delivery only after the mail adapter accepts the test message.
  class TestDeliveryJob < ApplicationJob
    queue_as :mailers
    self.enqueue_after_transaction_commit = true

    rescue_from StandardError do |error|
      record_test_failure(error)
      raise
    end

    # Retry only before-acceptance SMTP failures, not ambiguous delivery responses.
    retry_on Net::OpenTimeout, Errno::ECONNREFUSED, SocketError, Net::SMTPServerBusy,
             wait: :polynomially_longer, attempts: 3 do |job, error|
      job.send(:record_test_failure, error)
    end

    def perform(template_id, actor_id, recipient, version_id = nil)
      EmailTemplateTestMailer.sample(template_id, recipient, version_id).deliver_now
      template = EmailTemplate.find(template_id)
      begin
        template.audit!(action: 'test_delivered', actor: User.find_by(id: actor_id))
      rescue ActiveRecord::ActiveRecordError => e
        # Never re-send an accepted message solely because the audit store failed.
        Rails.logger.error("Test email delivery audit failed: #{e.class}")
      end
    end

    private

    def record_test_failure(error)
      template = EmailTemplate.find_by(id: arguments.first)
      actor = User.find_by(id: arguments.second)
      template&.audit!(action: 'test_failed', actor:, metadata: { error_class: error.class.name })
    rescue ActiveRecord::ActiveRecordError => audit_error
      Rails.logger.error("Test email failure audit failed: #{audit_error.class}")
    end
  end
end
