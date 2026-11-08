# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Concurrent branch transitions', :concurrent_db do
  it 'serializes simultaneous suspensions and creates exactly one change event' do
    organization = create(:organization)
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: admin)
    branch = create(:branch, organization:)
    barrier = Queue.new

    results = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          begin
            Branches::TransitionStatus.call(
              branch: Branch.find(branch.id), actor: User.find(admin.id),
              to: 'suspended', reason: 'Maintenance'
            )
            :changed
          rescue Branches::TransitionStatus::InvalidTransition
            :rejected
          end
        end
      end
    end
    2.times { barrier << true }
    expect(results.map(&:value).sort).to eq(%i[changed rejected])
    expect(branch.reload).to be_suspended
    expect(branch.branch_status_transitions.where(to_status: 'suspended').count).to eq(1)
  end
end
