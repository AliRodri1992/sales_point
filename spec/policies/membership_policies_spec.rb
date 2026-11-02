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
    expect(policy.create?).to be(false) # Only system super-administrators may create organizations.
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

  it 'scopes organizations and subscriptions to active memberships' do
    assigned = create(:organization)
    unrelated = create(:organization)
    create(:organization_membership, user: admin, organization: assigned)
    selected = create(:subscription, organization: assigned)
    create(:subscription, organization: unrelated)

    visible_organizations = OrganizationPolicy::Scope.new(admin, Organization.all).resolve
    visible_subscriptions = SubscriptionPolicy::Scope.new(admin, Subscription.all).resolve

    expect(visible_organizations).to contain_exactly(assigned)
    expect(visible_subscriptions).to contain_exactly(selected)
    expect(OrganizationPolicy::Scope.new(non_admin, Organization.all).resolve).to be_empty
    expect(SubscriptionPolicy::Scope.new(non_admin, Subscription.all).resolve).to be_empty
  end

  it 'allows system super-admins to see all organizations and subscriptions' do
    super_admin = create(:user)
    create(:user_role, user: super_admin, system_role: create(:system_role, :system, code: 'super_admin'))
    organization = create(:organization)
    membership = create(:subscription, organization:)

    expect(OrganizationPolicy.new(super_admin, organization).create?).to be(true)
    expect(OrganizationPolicy::Scope.new(super_admin, Organization.all).resolve).to include(organization)
    expect(SubscriptionPolicy::Scope.new(super_admin, Subscription.all).resolve).to include(membership)
  end

  it 'does not expose membership plans to ordinary users' do
    plan = create(:membership_plan)
    expect(MembershipPlanPolicy::Scope.new(admin, MembershipPlan.all).resolve).to include(plan)
    expect(MembershipPlanPolicy::Scope.new(non_admin, MembershipPlan.all).resolve).to be_empty
  end

  it 'denies anonymous access and returns empty scopes without a user' do
    organization = create(:organization)
    plan = create(:membership_plan)
    subscription = create(:subscription, organization:, membership_plan: plan)

    expect(OrganizationPolicy.new(nil, organization).index?).to be_falsey
    expect(OrganizationPolicy.new(nil, organization).create?).to be_falsey
    expect(OrganizationPolicy.new(nil, organization).destroy?).to be_falsey
    expect(MembershipPlanPolicy.new(nil, plan).index?).to be_falsey
    expect(SubscriptionPolicy.new(nil, subscription).index?).to be_falsey
    expect(SubscriptionPolicy.new(nil, subscription).cancel?).to be_falsey

    expect(OrganizationPolicy::Scope.new(nil, Organization.all).resolve).to be_empty
    expect(MembershipPlanPolicy::Scope.new(nil, MembershipPlan.all).resolve).to be_empty
    expect(SubscriptionPolicy::Scope.new(nil, Subscription.all).resolve).to be_empty
  end
end
