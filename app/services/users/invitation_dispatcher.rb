# frozen_string_literal: true

module Users
  class InvitationDispatcher
    def self.call(user:, organization:)
      EmailTemplate.ensure_invitation_template!
      invitation = UserInvitation.issue!(user:, organization:)
      UserInvitationMailer.invite(invitation.id, invitation.raw_token).deliver_later
    end
  end
end
