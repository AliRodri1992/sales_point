# frozen_string_literal: true

module MembershipSubscriptionFormHelpers
  private

  def subscription_organization_allowed?
    current_user.role?('super_admin') ||
      current_user.organization_memberships.active.exists?(organization_id: @subscription.organization_id)
  end

  def apply_trial_state
    return if @subscription.membership_plan.blank?
    return unless @subscription.membership_plan.trial_days.positive?

    @subscription.status = 'trialing'
    @subscription.trial_ends_at ||= @subscription.starts_at + @subscription.membership_plan.trial_days.days
  end

  def persist_new_subscription!
    Subscription.transaction do
      @subscription.save!
      record_creation_event!
    end
  end

  def record_creation_event!
    @subscription.subscription_events.create!(
      event_type: @subscription.trialing? ? 'trial_started' : 'subscription_created',
      membership_plan: @subscription.membership_plan,
      performed_by: current_user,
      to_status: @subscription.status,
      description: 'Subscription created.'
    )
  end

  def record_update_event(previous_plan)
    @subscription.subscription_events.create!(
      event_type: previous_plan == @subscription.membership_plan ? 'subscription_updated' : 'plan_changed',
      membership_plan: @subscription.membership_plan,
      performed_by: current_user,
      from_membership_plan_id: previous_plan.id,
      to_membership_plan_id: @subscription.membership_plan_id,
      to_status: @subscription.status,
      description: 'Subscription updated.'
    )
  end

  def notify_subscription(action)
    event = SubscriptionNotification.with(action:, record: @subscription, user: current_user)
    event.deliver(current_user, enqueue_job: false)
    current_user.broadcast_notifications_refresh
  end
end
