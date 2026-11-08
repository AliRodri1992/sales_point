# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::StatusTransition, type: :service do
  it 'does not count revoked admin roles when protecting the last administrator' do
    organization = create(:organization)
    role = create(:system_role, :system, code: 'administrator')
    target = create(:user, system_roles: [role], status: :active)
    create(:organization_membership, user: target, organization:, account_status: :active)
    former_admin = create(:user, status: :active)
    create(:organization_membership, user: former_admin, organization:, account_status: :active)
    create(:user_role, user: former_admin, system_role: role, deleted_at: 1.day.ago)

    transition = described_class.new(
      user: target, actor: former_admin, organization:, target: 'suspended', reason: 'Security review'
    )

    expect { transition.send(:prevent_last_admin!) }
      .to raise_error(ArgumentError, 'Cannot disable the last administrator')
  end
end
