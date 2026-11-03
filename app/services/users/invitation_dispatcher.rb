# frozen_string_literal: true

module Users
  class InvitationDispatcher
    class DeliveryError < StandardError; end

    def self.call(user:, organization:)
      EmailTemplate.ensure_invitation_template!
      invitation = UserInvitation.issue!(user:, organization:)
      encrypted_token = InvitationDeliveryToken.encrypt(invitation.raw_token)
      invitation.update!(delivery_status: 'queued', delivery_attempted_at: Time.current)
      enqueue!(invitation, encrypted_token)
      invitation
    end

    def self.enqueue!(invitation, encrypted_token)
      Users::InvitationDeliveryJob.perform_later(invitation.id, encrypted_token)
    rescue StandardError => e
      invitation.update!(delivery_status: 'failed')
      Rails.logger.error("Invitation mail enqueue failed: #{e.class}")
      raise DeliveryError, 'Invitation mail could not be queued'
    end
  end
end
