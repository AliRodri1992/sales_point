# frozen_string_literal: true

module Users
  # One set of invitation rules for admin actions, email links and restoration.
  class InvitationEligibility
    def self.ready?(user:, organization:)
      return false unless user && organization && user.deleted_at.nil?
      return false unless user.pending? || user.active?
      return false unless UserInvitation.pending_membership?(user:, organization:)

      roles_ready?(user:, organization:)
    end

    def self.roles_ready?(user:, organization:)
      return true unless user.employee?

      assignments = user.user_roles.active
      return true if assignments.exists?(branch_id: nil)

      branches = organization.branches.not_deleted.where(operational_status: 'active').select(:id)
      assignments.exists?(branch_id: branches)
    end
  end
end
