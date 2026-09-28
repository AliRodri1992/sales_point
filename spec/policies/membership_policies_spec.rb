# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Membership policies', type: :policy do
  let(:admin) { create(:user) }
  let(:non_admin) { create(:user) }
  let(:role) { create(:system_role, :system, code: 'administrator') }

  before do
    create(:user_role, user: admin, system_role: role)
  end

  it 'allows administrators to manage organizations' do
    policy = OrganizationPolicy.new(admin, Organization.new)

    expect(policy.index?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
  end

  it 'denies non-administrators organizations access' do
    policy = OrganizationPolicy.new(non_admin, Organization.new)

    expect(policy.index?).to be(false)
    expect(policy.create?).to be(false)
    expect(policy.update?).to be(false)
  end

  it 'allows administrators to manage membership plans and subscriptions' do
    expect(MembershipPlanPolicy.new(admin, MembershipPlan.new).index?).to be(true)
    expect(SubscriptionPolicy.new(admin, Subscription.new).index?).to be(true)
    expect(SubscriptionPolicy.new(admin, Subscription.new).change_plan?).to be(true)
  end

  it 'denies non-administrators membership plan and subscription access' do
    expect(MembershipPlanPolicy.new(non_admin, MembershipPlan.new).index?).to be(false)
    expect(SubscriptionPolicy.new(non_admin, Subscription.new).index?).to be(false)
    expect(SubscriptionPolicy.new(non_admin, Subscription.new).change_plan?).to be(false)
  end
end
