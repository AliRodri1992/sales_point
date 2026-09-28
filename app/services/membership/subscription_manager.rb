# frozen_string_literal: true

module Membership
  class SubscriptionManager
    def initialize(subscription, actor: nil)
      @subscription = subscription
      @actor = actor
    end

    def change_plan!(new_plan)
      old_plan = subscription.membership_plan
      return subscription if old_plan == new_plan

      Subscription.transaction do
        subscription.update!(membership_plan: new_plan)
        record_event!(
          'plan_changed',
          from_membership_plan_id: old_plan.id,
          to_membership_plan_id: new_plan.id,
          membership_plan: new_plan,
          description: "Plan changed from #{old_plan.name} to #{new_plan.name}."
        )
      end

      subscription
    end

    def pause!
      ensure_status!('trialing', 'active')
      transition!('paused')
    end

    def resume!
      ensure_status!('paused')
      transition!(subscription.trialing? ? 'trialing' : 'active')
    end

    def cancel!
      ensure_status!('trialing', 'active', 'past_due', 'paused')
      from_status = subscription.status

      Subscription.transaction do
        subscription.update!(status: 'canceled', canceled_at: Time.current)
        record_event!(
          'canceled',
          from_status:,
          to_status: 'canceled',
          description: 'Subscription canceled.'
        )
      end
      subscription
    end

    private

    attr_reader :subscription, :actor

    def ensure_status!(*allowed_statuses)
      return if allowed_statuses.include?(subscription.status)

      subscription.errors.add(:status, :invalid, message: "cannot transition from #{subscription.status}")
      raise ActiveRecord::RecordInvalid, subscription
    end

    def transition!(status)
      from_status = subscription.status

      Subscription.transaction do
        subscription.update!(status:)
        record_event!(
          status == 'paused' ? 'paused' : 'resumed',
          from_status:,
          to_status: status,
          description: "Subscription status changed from #{from_status} to #{status}."
        )
      end

      subscription
    end

    def record_event!(event_type, membership_plan: nil, **attributes)
      subscription.subscription_events.create!(
        membership_plan:,
        performed_by: actor,
        event_type:,
        **attributes
      )
    end
  end
end
