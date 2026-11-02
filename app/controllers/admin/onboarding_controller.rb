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
      load_onboarding
      return update_recovery if params[:intent].present?

      if Onboarding::StepUpdater.call(organization: @organization, step: @step, params:, user: current_user,
                                      branch: @branch, settings: @settings, terminals: @terminals)
        handle_update_success
      else
        handle_update_failure
      end
    end

    private

    def set_organization
      membership = current_user.organization_memberships.active.joins(:organization)
                               .merge(Organization.active_records).first
      @organization = membership&.organization
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
      @currencies = Currency.active.order(:code)
      @step = normalized_step
      load_business
      @migration = @organization.organization_migrations.first
      @progress = Onboarding::ProgressCalculator.call(@organization)
      @employees = @organization.employees.active.order(:id).to_a
      @team_member = Employee.new(organization_id: @organization.id, email: current_user.email)
      @new_terminal = Terminal.new(name: t('registration.initial_terminal_name', number: 1))
    end

    def load_business
      @branch = active_branch || Branch.new(organization_id: @organization.id,
                                            name: t('registration.initial_branch_name'), status: true)
      @settings = @organization.organization_settings.first ||
                  OrganizationSetting.new(organization_id: @organization.id, payment_method: :cash)
      @terminals = terminals_for(@branch)
      @branch.build_address if @branch.address.nil?
    end

    def terminals_for(branch)
      return [] unless branch&.persisted?

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
      Onboarding::Auditor.call(organization: @organization, user: current_user, action: 'reset',
                               metadata: { 'reason' => 'administrative_reset' })
    end

    def update_recovery
      intent = params[:intent]
      return head :unprocessable_content unless { 'terminal' => 3, 'team' => 5 }[intent] == @step

      record = intent == 'terminal' ? @new_terminal : @team_member
      result = Onboarding::RecoveryUpdater.call(organization: @organization, user: current_user,
                                                intent:, params:, record:, branch: @branch)
      if result
        redirect_to admin_onboarding_path(step: @step),
                    flash: { swal_message: t('admin.onboarding_ui.feedback.recovered') }
      else
        handle_update_failure
      end
    end

    def success_path
      return admin_dashboard_path if @step == 5 || params[:destination] == 'dashboard'

      admin_onboarding_path(step: @step + 1)
    end

    def handle_update_success
      key = @step == 5 ? 'completed' : 'saved'
      flash[:swal_message] = t("admin.onboarding_ui.feedback.#{key}")
      redirect_to success_path
    end

    def handle_update_failure
      @onboarding_error = t('admin.onboarding_ui.feedback.incomplete')
      render :show, status: :unprocessable_content
    end
  end
end
