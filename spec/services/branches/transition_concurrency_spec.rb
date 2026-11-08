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
  it 'never writes a sale after a suspension wins the branch lock' do
    organization = create(:organization)
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: admin)
    branch = create(:branch, organization:)
    product = create(:product, organization:)
    inventory = create(:inventory, organization:, branch:, product:, stock: 5)
    barrier = Queue.new

    suspension = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        Branches::TransitionStatus.call(
          branch: Branch.find(branch.id), actor: User.find(admin.id),
          to: 'suspended', reason: 'Emergency maintenance'
        )
      end
    end
    sale = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Inventories::ApplyMovement.call(
            inventory: Inventory.find(inventory.id), quantity: -1, kind: 'sale'
          )
          :recorded
        rescue ActiveRecord::RecordInvalid
          :blocked
        end
      end
    end
    2.times { barrier << true }
    expect(suspension.value).to be(true)
    expect(%i[recorded blocked]).to include(sale.value)
    expect(branch.reload).to be_suspended

    movements = inventory.inventory_movements.where(kind: 'sale').count
    expect(inventory.reload.stock).to eq(5 - movements)
    expect(movements).to be_between(0, 1)
  end

  it 'cannot close a branch and concurrently add an active role to it' do
    organization = create(:organization)
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: admin)
    employee = create(:user)
    branch = create(:branch, organization:)
    role = create(:system_role, :branch)
    barrier = Queue.new

    closure = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          Branches::TransitionStatus.call(
            branch: Branch.find(branch.id), actor: User.find(admin.id),
            to: 'closed', reason: 'Permanent closure'
          )
          :closed
        rescue Branches::TransitionStatus::InvalidTransition
          :blocked
        end
      end
    end
    assignment = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        begin
          user_role = UserRole.new(user: User.find(employee.id),
                                   system_role: SystemRole.find(role.id), branch: Branch.find(branch.id))
          user_role.save ? :assigned : :blocked
        rescue ActiveRecord::RecordInvalid
          :blocked
        end
      end
    end
    2.times { barrier << true }
    expect(%i[closed blocked]).to include(closure.value)
    expect(%i[assigned blocked]).to include(assignment.value)

    if branch.reload.closed?
      expect(UserRole.active.where(branch_id: branch.id)).not_to exist
    else
      expect(UserRole.active.where(branch_id: branch.id)).to exist
    end
  end

end
