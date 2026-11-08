# frozen_string_literal: true

module EmailTemplates
  # Record delivery only after the mail adapter accepts the test message.
  class TestDeliveryJob < ApplicationJob
    queue_as :mailers

    retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
      template = EmailTemplate.find_by(id: job.arguments.first)
      actor = User.find_by(id: job.arguments.second)
      template&.audit!(action: 'test_failed', actor:, metadata: { error_class: error.class.name })
    end

    def perform(template_id, actor_id, recipient, version_id = nil)
      EmailTemplateTestMailer.sample(template_id, recipient, version_id).deliver_now
      template = EmailTemplate.find(template_id)
      template.audit!(action: 'test_delivered', actor: User.find_by(id: actor_id))
    end
  end
end
