# frozen_string_literal: true

module Admin
  class OnboardingController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_organization
    before_action :authorize_onboarding

    def show
      load_onboarding
    end

    def update
      @step = normalized_step

      if Onboarding::StepUpdater.call(organization: @organization, step: @step, params: params)
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
      authorize :onboarding, :show?
    end

    def normalized_step
      value = params[:step].to_i
      value.between?(1, 5) ? value : 1
    end

    def load_onboarding
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

    def success_path
      if @step == 5
        admin_dashboard_path
      else
        admin_onboarding_path(step: @step + 1)
      end
    end

    def handle_update_failure
      load_onboarding
      flash.now[:alert] = t('admin.onboarding.incomplete')
      render :show, status: :unprocessable_content
    end
  end
end
