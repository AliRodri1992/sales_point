# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Subscription lifecycle administration', type: :request do
  let!(:role) { create(:system_role, :system, code: 'administrator') }
  let!(:admin) { create(:user) }
  let!(:organization) { create(:organization) }
  let!(:plan) { create(:membership_plan, trial_days: 0) }
  let!(:new_plan) { create(:membership_plan, position: 2) }
  let!(:subscription) { create(:subscription, organization:, membership_plan: plan, status: :active) }

  before do
    create(:user_role, user: admin, system_role: role)
    sign_in admin
  end

  after { sign_out admin }

  it 'changes the plan and records the event' do
    patch change_plan_admin_subscription_path(subscription),
          params: { membership_plan_id: new_plan.id }

    expect(response).to redirect_to(admin_subscription_path(subscription))
    expect(subscription.reload.membership_plan).to eq(new_plan)
    expect(subscription.subscription_events.last.event_type).to eq('plan_changed')
  end

  it 'pauses and resumes a subscription' do
    patch pause_admin_subscription_path(subscription)
    expect(subscription.reload).to be_paused

    patch resume_admin_subscription_path(subscription)
    expect(subscription.reload).to be_active
  end

  it 'cancels a subscription and records the actor' do
    patch cancel_admin_subscription_path(subscription)

    event = subscription.reload.subscription_events.last

    expect(response).to redirect_to(admin_subscription_path(subscription))
    expect(subscription).to be_canceled
    expect(event.event_type).to eq('canceled')
    expect(event.performed_by).to eq(admin)
    expect(event.from_status).to eq('active')
    expect(event.to_status).to eq('canceled')
  end
end
