# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Membership plan administration', type: :request do
  let!(:role) { create(:system_role, :system, code: 'administrator') }
  let!(:admin) { create(:user) }
  let!(:plan) { create(:membership_plan) }
  let!(:feature) { create(:membership_feature, key: 'max_users', value_type: :integer) }

  before do
    create(:user_role, user: admin, system_role: role)
    sign_in admin
  end

  after { sign_out admin }

  it 'creates a plan with selected feature limits' do
    post admin_membership_plans_path,
         params: {
           membership_plan: {
             name: 'Professional',
             slug: 'professional',
             description: 'Professional plan',
             price: '599',
             currency: 'MXN',
             billing_interval: 'monthly',
             trial_days: '14',
             position: '2',
             active: '1'
           },
           feature_ids: [feature.id],
           feature_limits: { feature.id.to_s => '10' },
           feature_values: { feature.id.to_s => 'true' }
         }

    created = MembershipPlan.find_by!(slug: 'professional')
    assignment = created.membership_plan_features.find_by!(membership_feature: feature)

    expect(response).to redirect_to(admin_membership_plan_path(created))
    expect(assignment.limit).to eq(10)
    expect(assignment).to be_enabled
  end

  it 'soft deletes a previously selected feature when it is removed' do
    assignment = create(:membership_plan_feature, membership_plan: plan, membership_feature: feature)

    patch admin_membership_plan_path(plan),
          params: {
            membership_plan: {
              name: plan.name,
              slug: plan.slug,
              description: plan.description,
              price: plan.price,
              currency: plan.currency,
              billing_interval: plan.billing_interval,
              trial_days: plan.trial_days,
              position: plan.position,
              active: plan.active
            },
            feature_ids: []
          }

    expect(response).to redirect_to(admin_membership_plan_path(plan))
    expect(assignment.reload.deleted_at).to be_present
    expect(plan.reload.membership_features).to be_empty
  end

  it 'reactivates a previously soft-deleted feature assignment' do
    assignment = create(:membership_plan_feature, membership_plan: plan,
                                                    membership_feature: feature,
                                                    deleted_at: Time.current)

    patch admin_membership_plan_path(plan),
          params: {
            membership_plan: {
              name: plan.name,
              slug: plan.slug,
              description: plan.description,
              price: plan.price,
              currency: plan.currency,
              billing_interval: plan.billing_interval,
              trial_days: plan.trial_days,
              position: plan.position,
              active: plan.active
            },
            feature_ids: [feature.id],
            feature_limits: { feature.id.to_s => '25' }
          }

    expect(response).to redirect_to(admin_membership_plan_path(plan))
    expect(assignment.reload.deleted_at).to be_nil
    expect(assignment.limit).to eq(25)
  end
end
