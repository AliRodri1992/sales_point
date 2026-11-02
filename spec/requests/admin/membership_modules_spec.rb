# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Membership administration', type: :request do
  let!(:role) { create(:system_role, :system, code: 'super_admin') }
  let!(:admin) { create(:user) }

  before do
    create(:user_role, user: admin, system_role: role)
    sign_in admin
  end

  after { sign_out admin }

  it 'protects organization, plan and subscription endpoints with Pundit' do
    get admin_organizations_path
    expect(response).to have_http_status(:ok)

    get admin_membership_plans_path
    expect(response).to have_http_status(:ok)

    get admin_subscriptions_path
    expect(response).to have_http_status(:ok)
  end

  it 'creates an organization and returns a SweetAlert2 flash' do
    post admin_organizations_path,
         params: {
           organization: {
             name: 'Delta Demo',
             tax_id: 'ABC010101AB1',
             business_sector: 'grocery',
             status: 'active'
           }
         }

    expect(response).to redirect_to(admin_organization_path(Organization.find_by!(tax_id: 'ABC010101AB1')))
    expect(flash[:swal_message]).to eq(I18n.t('admin.organizations.created'))
  end

  it 'creates a subscription and records its event' do
    organization = create(:organization)
    plan = create(:membership_plan)

    post admin_subscriptions_path,
         params: {
           subscription: {
             organization_id: organization.id,
             membership_plan_id: plan.id,
             status: 'active',
             starts_at: Time.current
           }
         }

    subscription = organization.reload.subscriptions.current.first
    expect(response).to redirect_to(admin_subscription_path(subscription))
    expect(subscription.subscription_events).to exist
  end

  it 'renders new and edit organization forms and updates a registered organization' do
    organization = create(:organization)
    get new_admin_organization_path
    expect(response).to have_http_status(:ok)

    get edit_admin_organization_path(organization)
    expect(response).to have_http_status(:ok)

    patch admin_organization_path(organization), params: { organization: { name: 'Delta Updated' } }
    expect(response).to redirect_to(admin_organization_path(organization))
    expect(organization.reload.name).to eq('Delta Updated')
  end

  it 'keeps invalid organization changes visible with field errors' do
    organization = create(:organization)
    post admin_organizations_path,
         params: { organization: { name: 'X', tax_id: 'BAD', business_sector: 'unknown', status: 'active' } }
    expect(response).to have_http_status(:unprocessable_content)

    patch admin_organization_path(organization), params: { organization: { tax_id: 'BAD' } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'shows plan administration screens and updates an existing plan' do
    plan = create(:membership_plan)
    get new_admin_membership_plan_path
    expect(response).to have_http_status(:ok)
    get admin_membership_plan_path(plan)
    expect(response).to have_http_status(:ok)
    get edit_admin_membership_plan_path(plan)
    expect(response).to have_http_status(:ok)

    patch admin_membership_plan_path(plan), params: { membership_plan: { name: 'Updated Plan' } }
    expect(response).to redirect_to(admin_membership_plan_path(plan))
    expect(plan.reload.name).to eq('Updated Plan')
  end

  it 'rejects invalid plan creation and updates without partial persistence' do
    plan = create(:membership_plan)
    post admin_membership_plans_path, params: { membership_plan: { name: 'X', slug: 'invalid slug' } }
    expect(response).to have_http_status(:unprocessable_content)

    patch admin_membership_plan_path(plan), params: { membership_plan: { slug: 'invalid slug' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(plan.reload.slug).not_to eq('invalid slug')
  end

  it 'creates an active trial subscription when the plan provides trial days' do
    organization = create(:organization)
    plan = create(:membership_plan, trial_days: 7)
    post admin_subscriptions_path,
         params: { subscription: { organization_id: organization.id, membership_plan_id: plan.id,
                                   status: 'active', starts_at: Time.current } }

    created = organization.subscriptions.first
    expect(response).to redirect_to(admin_subscription_path(created))
    expect(created).to be_trialing
    expect(created.trial_ends_at).to be_present
    expect(created.subscription_events.last.event_type).to eq('trial_started')
  end

  it 'rejects subscription creation without a plan' do
    organization = create(:organization)
    post admin_subscriptions_path,
         params: { subscription: { organization_id: organization.id, status: 'active',
                                   starts_at: Time.current } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'shows and updates a subscription and records an update event' do
    organization = create(:organization)
    plan = create(:membership_plan, trial_days: 0)
    subscription = create(:subscription, organization:, membership_plan: plan)
    get new_admin_subscription_path
    expect(response).to have_http_status(:ok)
    get admin_subscription_path(subscription)
    expect(response).to have_http_status(:ok)
    get edit_admin_subscription_path(subscription)
    expect(response).to have_http_status(:ok)

    patch admin_subscription_path(subscription), params: { subscription: { status: 'past_due' } }
    expect(response).to redirect_to(admin_subscription_path(subscription))
    expect(subscription.reload.status).to eq('past_due')
    expect(subscription.subscription_events.last.event_type).to eq('subscription_updated')
  end

  it 'renders validation errors when changing a subscription to an invalid status' do
    subscription = create(:subscription)
    patch admin_subscription_path(subscription), params: { subscription: { status: 'invalid' } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
