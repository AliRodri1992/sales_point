# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Concurrent last administrator role removal', :concurrent_db do
  it 'keeps an active administrator when both administrators remove their roles simultaneously' do
    organization = create(:organization)
    root = create(:system_role, :system, code: 'super_admin')
    first = create(:user, user_type: 'customer', system_roles: [root])
    second = create(:user, user_type: 'customer', system_roles: [root])
    create(:organization_membership, user: first, organization:)
    create(:organization_membership, user: second, organization:)
    barrier = Queue.new

    workers = [first.id, second.id].map do |id|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          target = User.find(id)
          actor = target
          writer = Users::AdminAccountWriter.new(
            user: target, actor:, organization: Organization.find(organization.id),
            attributes: { system_role_ids: [] }
          )
          barrier.pop
          writer.save
        end
      end
    end
    2.times { barrier << true }
    expect(workers.map(&:value)).to contain_exactly(true, false)

    active_roots = UserRole.active.where(user_id: [first.id, second.id], branch_id: nil)
    expect(active_roots.count).to eq(1)
  end
end
