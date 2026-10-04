# frozen_string_literal: true

module Admin
  class OnboardingController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_organization
    before_action :authorize_onboarding

    def show
      return redirect_to admin_dashboard_path if @organization.onboarding_completed?

      start_onboarding
      load_onboarding
    end

    def reset
      ApplicationRecord.transaction do
        @organization.update!(reset_attributes)
        log_reset_action
      end

      redirect_to admin_onboarding_path(step: 1), flash: { swal_message: t('admin.onboarding.reset') }
    end

    def update
      @step = normalized_step

      if Onboarding::StepUpdater.call(organization: @organization, step: @step, params:, user: current_user)
        flash[:swal_message] = t('admin.onboarding.completed') if @step == 5
        redirect_to success_path
      else
        handle_update_failure
      end
    end

    private

    def set_organization
      @organization = current_user.organizations.active_records.first
      raise ActiveRecord::RecordNotFound unless @organization
    end

    def authorize_onboarding
      authorize :onboarding, "#{action_name}?"
    end

    def start_onboarding
      was_pending = @organization.onboarding_status == 'pending'
      @organization.start_onboarding!
      Onboarding::ProgressSynchronizer.call(organization: @organization)
      return unless was_pending

      Onboarding::Auditor.call(
        organization: @organization,
        user: current_user,
        action: 'started',
        step: @organization.onboarding_current_step,
        metadata: { 'percentage' => Onboarding::ProgressCalculator.call(@organization)[:percentage] }
      )
    end

    def normalized_step
      value = params[:step].to_i
      return @organization.onboarding_current_step if params[:step].blank?

      value.between?(1, 5) ? value : 1
    end

    def load_onboarding
      @progress_percentage = Onboarding::ProgressCalculator.call(@organization)[:percentage]
      @step = normalized_step
      @branch = active_branch
      @settings = @organization.organization_settings.first
      @terminals = terminals_for(@branch)
      @migration = @organization.organization_migrations.first
      @progress = Onboarding::ProgressCalculator.call(@organization)
      @branch.build_address if @branch && @branch.address.nil?
    end

    def terminals_for(branch)
      return [] unless branch

      branch.terminals.active_records.order(:id)
    end

    def active_branch
      @organization.branches.not_deleted.where(status: true).first ||
        @organization.branches.not_deleted.first
    end

    def reset_attributes
      {
        onboarding_status: :pending,
        onboarding_current_step: 1,
        onboarding_sections: {},
        onboarding_completed_at: nil
      }
    end

    def log_reset_action
      Onboarding::Auditor.call(
        organization: @organization,
        user: current_user,
        action: 'reset',
        metadata: { 'reason' => 'administrative_reset' }
      )
    end

    def success_path
      return admin_dashboard_path if @step == 5

      admin_onboarding_path(step: @step + 1)
    end

    def handle_update_failure
      load_onboarding
      flash.now[:swal_message] = t('admin.onboarding.incomplete')
      flash.now[:swal_icon] = 'error'
      render :show, status: :unprocessable_content
    end
  end
end
