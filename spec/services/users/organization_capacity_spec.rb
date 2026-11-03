# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::OrganizationCapacity do
  let(:organization) { create(:organization) }
  let(:plan) { create(:membership_plan) }

  before do
    feature = MembershipFeature.find_or_create_by!(key: 'users_limit') do |item|
      item.name = 'User seats'
      item.value_type = :integer
    end
    MembershipPlanFeature.create!(membership_plan: plan, membership_feature: feature, limit: 2)
    organization.update!(membership_plan: plan)
  end

  it 'reserves seats for pending and suspended users but frees deleted seats' do
    first_user = create(:user)
    second_user = create(:user)
    create(:organization_membership, user: first_user, organization:, account_status: :pending)
    create(:organization_membership, user: second_user, organization:, account_status: :suspended)

    capacity = described_class.new(organization:)
    expect(capacity.occupied).to eq(2)
    expect { capacity.ensure_available! }.to raise_error(Users::OrganizationCapacity::CapacityExceeded)

    second_user.organization_memberships.find_by!(organization:).update!(account_status: :deleted)
    expect(capacity.occupied).to eq(1)
    expect { capacity.ensure_available! }.not_to raise_error
  end

  it 'does not impose a limit without an assigned plan' do
    organization.update!(membership_plan: nil)
    expect(described_class.new(organization:).limit).to be_nil
  end
end
