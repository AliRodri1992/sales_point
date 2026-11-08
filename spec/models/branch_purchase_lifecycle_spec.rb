# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase requests and branch lifecycle', type: :model do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:requester) { create(:user) }

  it 'allows creating purchase requests only while the branch is operational' do
    request = PurchaseRequest.create!(
      organization:, branch:, requested_by: requester, status: 'draft'
    )
    expect(request).to be_persisted

    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: admin)
    Branches::TransitionStatus.call(branch:, actor: admin, to: 'suspended', reason: 'Maintenance')

    blocked = PurchaseRequest.new(
      organization:, branch:, requested_by: requester, status: 'draft'
    )
    expect(blocked).not_to be_valid
    expect(blocked.errors[:branch]).to be_present
  end

  it 'rejects transferring an existing purchase request to a suspended branch' do
    request = PurchaseRequest.create!(
      organization:, branch:, requested_by: requester, status: 'draft'
    )
    other = create(:branch, organization:, name: 'Paused office', status: false)

    expect(request.update(branch: other)).to be(false)
    expect(request.errors[:branch]).to be_present
    expect(request.reload.branch_id).to eq(branch.id)
  end
end
