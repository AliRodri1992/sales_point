# frozen_string_literal: true

module Users
  class InvitationDispatcher
    def self.call(user:, organization:)
      EmailTemplate.ensure_invitation_template!
      invitation = UserInvitation.issue!(user:, organization:)
      encrypted_token = InvitationDeliveryToken.encrypt(invitation.raw_token)
      UserInvitationMailer.invite(invitation.id, encrypted_token).deliver_later
      invitation.update!(delivery_status: 'queued', delivery_attempted_at: Time.current)
    end
  end
end
