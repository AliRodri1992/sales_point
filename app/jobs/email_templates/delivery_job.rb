# frozen_string_literal: true

module EmailTemplates
  class DeliveryJob < ApplicationJob
    queue_as :mailers
    self.enqueue_after_transaction_commit = true

    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    discard_on ActiveJob::DeserializationError

    def perform(ciphertext)
      payload = EncryptedPayload.decrypt(ciphertext)
      EmailTemplates::TransactionalMailer.notification(
        payload.fetch(:template_id), payload.fetch(:recipient), payload.fetch(:values),
        payload[:organization_id], { version_id: payload[:version_id], sender_headers: payload[:sender_headers] }
      ).deliver_now
    end
  end
end
