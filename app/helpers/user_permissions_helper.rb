# frozen_string_literal: true

module UserPermissionsHelper
  def allowed_user_transitions(user, organization:)
    return [] unless policy(user).manage_status?

    status = user.organization_memberships.active.find_by(organization:)&.account_status
    Users::StatusTransition.allowed_targets(user, organization:).select do |target|
      permission = if status == 'blocked' && target != 'deleted'
                     'users.unblock'
                   else
                     Users::StatusTransition::PERMISSIONS.fetch(target)
                   end
      current_user.permission?(permission, organization:)
    end
  end
end
