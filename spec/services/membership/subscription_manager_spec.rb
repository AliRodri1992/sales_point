# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Membership::SubscriptionManager, type: :service do
  let(:organization) { create(:organization) }
  let(:old_plan) { create(:membership_plan, position: 1) }
  let(:new_plan) { create(:membership_plan, position: 2) }
  let(:subscription) { create(:subscription, organization:, membership_plan: old_plan) }
  let(:actor) { create(:user) }

  it 'changes the plan and records an event' do
    described_class.new(subscription, actor:).change_plan!(new_plan)

    expect(subscription.reload.membership_plan).to eq(new_plan)
    expect(subscription.subscription_events.last.event_type).to eq('plan_changed')
    expect(subscription.subscription_events.last.performed_by).to eq(actor)
  end

  it 'pauses and resumes a subscription' do
    manager = described_class.new(subscription, actor:)

    manager.pause!
    expect(subscription.reload).to be_paused

    manager.resume!
    expect(subscription.reload).to be_active
  end

  it 'cancels a subscription and records the transition' do
    described_class.new(subscription, actor:).cancel!

    expect(subscription.reload).to be_canceled
    expect(subscription.subscription_events.last.from_status).to eq('active')
    expect(subscription.subscription_events.last.to_status).to eq('canceled')
  end
end
