# frozen_string_literal: true

module Users
  class InvitationDeliveryJob < ApplicationJob
    queue_as :mailers

    retry_on StandardError, wait: :polynomially_longer, attempts: 5
    discard_on ActiveJob::DeserializationError

    def perform(invitation_id, encrypted_token)
      invitation = UserInvitation.find_by(id: invitation_id)
      return unless invitation&.usable?

      invitation.update!(delivery_attempted_at: Time.current, delivery_status: 'queued')
      UserInvitationMailer.invite(invitation_id, encrypted_token).deliver_now
    rescue StandardError
      invitation&.update!(delivery_status: 'failed')
      raise
    end
  end
end
