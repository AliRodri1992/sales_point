# frozen_string_literal: true

module Admin
  class SubscriptionsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_subscription, only: %i[show edit update change_plan pause resume cancel]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden

    def index
      authorize Subscription
      @subscriptions = policy_scope(Subscription)
                       .includes(:organization, :membership_plan)
                       .order(created_at: :desc)
    end

    def show
      authorize @subscription
      @events = @subscription.subscription_events
                              .includes(:performed_by, :from_membership_plan, :to_membership_plan)
                              .order(created_at: :desc)
    end

    def new
      @subscription = Subscription.new(starts_at: Time.current)
      authorize @subscription
      load_form_options
    end

    def create
      @subscription = Subscription.new(subscription_params)
      authorize @subscription
      @subscription.starts_at ||= Time.current

      apply_trial_state

      Subscription.transaction do
        @subscription.save!
        @subscription.subscription_events.create!(
          event_type: @subscription.trialing? ? 'trial_started' : 'subscription_created',
          membership_plan: @subscription.membership_plan,
          performed_by: current_user,
          to_status: @subscription.status,
          description: 'Subscription created.'
        )
      end

      notify_subscription('created')
      redirect_to admin_subscription_path(@subscription),
                  flash: { swal_message: t('admin.subscriptions.created') }
    rescue ActiveRecord::RecordInvalid
      load_form_options
      render :new, status: :unprocessable_content
    end

    def edit
      authorize @subscription
      load_form_options
    end

    def update
      authorize @subscription
      previous_plan = @subscription.membership_plan

      if @subscription.update(subscription_params)
        record_update_event(previous_plan)
        notify_subscription(previous_plan != @subscription.membership_plan ? 'plan_changed' : 'updated')
        redirect_to admin_subscription_path(@subscription),
                    flash: { swal_message: t('admin.subscriptions.updated') }
      else
        load_form_options
        render :edit, status: :unprocessable_content
      end
    end

    def change_plan
      authorize @subscription, :change_plan?
      new_plan = MembershipPlan.where(deleted_at: nil).find(params[:membership_plan_id])
      Membership::SubscriptionManager.new(@subscription, actor: current_user).change_plan!(new_plan)
      notify_subscription('plan_changed')
      redirect_to admin_subscription_path(@subscription),
                  flash: { swal_message: t('admin.subscriptions.plan_changed') }
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_subscription_path(@subscription),
                  flash: { swal_message: e.record.errors.full_messages.to_sentence }
    end

    def pause
      authorize @subscription, :pause?
      Membership::SubscriptionManager.new(@subscription, actor: current_user).pause!
      notify_subscription('paused')
      redirect_to admin_subscription_path(@subscription),
                  flash: { swal_message: t('admin.subscriptions.paused') }
    end

    def resume
      authorize @subscription, :resume?
      Membership::SubscriptionManager.new(@subscription, actor: current_user).resume!
      notify_subscription('resumed')
      redirect_to admin_subscription_path(@subscription),
                  flash: { swal_message: t('admin.subscriptions.resumed') }
    end

    def cancel
      authorize @subscription, :cancel?
      Membership::SubscriptionManager.new(@subscription, actor: current_user).cancel!
      notify_subscription('canceled')
      redirect_to admin_subscription_path(@subscription),
                  flash: { swal_message: t('admin.subscriptions.canceled') }
    end

    private

    def set_subscription
      @subscription = policy_scope(Subscription).find(params[:id])
    end

    def subscription_params
      params.expect(
        subscription: %i[organization_id membership_plan_id status starts_at ends_at trial_ends_at]
      )
    end

    def load_form_options
      @organizations = Organization.active.order(:name)
      @membership_plans = MembershipPlan.where(deleted_at: nil).order(:position, :name)
    end

    def apply_trial_state
      return if @subscription.membership_plan.blank?
      return unless @subscription.membership_plan.trial_days.positive?

      @subscription.status = 'trialing'
      @subscription.trial_ends_at ||= @subscription.starts_at + @subscription.membership_plan.trial_days.days
    end

    def record_update_event(previous_plan)
      @subscription.subscription_events.create!(
        event_type: previous_plan != @subscription.membership_plan ? 'plan_changed' : 'subscription_updated',
        membership_plan: @subscription.membership_plan,
        performed_by: current_user,
        from_membership_plan_id: previous_plan.id,
        to_membership_plan_id: @subscription.membership_plan_id,
        to_status: @subscription.status,
        description: 'Subscription updated.'
      )
    end

    def notify_subscription(action)
      SubscriptionNotification.with(action:, record: @subscription, user: current_user)
                              .deliver(current_user, enqueue_job: false)
      current_user.broadcast_notifications_refresh
    end

    def forbidden
      head :forbidden
    end
  end
end
