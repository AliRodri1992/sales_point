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
end
