# frozen_string_literal: true

module Admin
  class MembershipPlansController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_membership_plan, only: %i[show edit update]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden

    def index
      authorize MembershipPlan
      @membership_plans = policy_scope(MembershipPlan)
                          .includes(:membership_features)
                          .order(:position, :name)
    end

    def show
      authorize @membership_plan
      @plan_features = @membership_plan.membership_plan_features
                                        .where(deleted_at: nil)
                                        .includes(:membership_feature)
                                        .order(:position)
    end

    def new
      @membership_plan = MembershipPlan.new(
        active: true,
        billing_interval: :monthly,
        currency: 'MXN',
        trial_days: 14,
        position: 0
      )
      authorize @membership_plan
      load_features
    end

    def create
      @membership_plan = MembershipPlan.new(membership_plan_params)
      authorize @membership_plan

      MembershipPlan.transaction do
        @membership_plan.save!
        sync_features!
      end

      notify_plan('created')
      redirect_to admin_membership_plan_path(@membership_plan),
                  flash: { swal_message: t('admin.membership_plans.created') }
    rescue ActiveRecord::RecordInvalid
      load_features
      render :new, status: :unprocessable_content
    end

    def edit
      authorize @membership_plan
      load_features
    end

    def update
      authorize @membership_plan

      MembershipPlan.transaction do
        @membership_plan.update!(membership_plan_params)
        sync_features!
      end

      notify_plan('updated')
      redirect_to admin_membership_plan_path(@membership_plan),
                  flash: { swal_message: t('admin.membership_plans.updated') }
    rescue ActiveRecord::RecordInvalid
      load_features
      render :edit, status: :unprocessable_content
    end

    private

    def set_membership_plan
      @membership_plan = policy_scope(MembershipPlan).find(params[:id])
    end

    def membership_plan_params
      params.expect(
        membership_plan: %i[
          name slug description price currency billing_interval trial_days position active
        ]
      )
    end

    def load_features
      @features = MembershipFeature.where(deleted_at: nil).order(:position, :name)
      @selected_features = @membership_plan.membership_plan_features.index_by(&:membership_feature_id)
    end

    def sync_features!
      selected_ids = Array(params[:feature_ids]).compact_blank.map(&:to_i)
      values = params[:feature_values] || {}
      limits = params[:feature_limits] || {}
      enabled = Array(params[:feature_ids]).compact_blank.map(&:to_i)

      @membership_plan.membership_plan_features.where.not(membership_feature_id: selected_ids).update_all(deleted_at: Time.current)

      selected_ids.each_with_index do |feature_id, index|
        plan_feature = @membership_plan.membership_plan_features
                                       .find_or_initialize_by(membership_feature_id: feature_id)
        plan_feature.assign_attributes(
          enabled: enabled.include?(feature_id),
          value: values[feature_id.to_s],
          limit: limits[feature_id.to_s].presence,
          position: index,
          deleted_at: nil
        )
        plan_feature.save!
      end
    end

    def notify_plan(action)
      MembershipPlanNotification.with(action:, record: @membership_plan, user: current_user)
                                 .deliver(current_user, enqueue_job: false)
      current_user.broadcast_notifications_refresh
    end

    def forbidden
      head :forbidden
    end
  end
end
