# frozen_string_literal: true

module Onboarding
  class StepUpdater
    def self.call(organization:, step:, params:, user:)
      new(organization, step, params, user).call
    end

    def initialize(organization, step, params, user)
      @organization = organization
      @step = step
      @params = params
      @user = user
    end

    def call
      result = execute_step
      return false unless result

      persist_progress
      advance_step if @step == @organization.onboarding_current_step && @step < 5
      audit_step
      true
    rescue ActiveRecord::RecordInvalid, KeyError, ActionController::ParameterMissing
      false
    end

    private

    def execute_step
      case @step
      when 1 then CompanyUpdater.call(@organization, @params)
      when 2 then BranchUpdater.call(@organization, @params)
      when 3 then TerminalsUpdater.call(@organization, @params)
      when 4 then PaymentUpdater.call(@organization, @params)
      when 5 then complete_onboarding?
      else false
      end
    end

    def complete_onboarding?
      progress = Onboarding::ProgressCalculator.call(@organization)
      return false unless progress[:sections].all? { |section| section[:percentage] == 100 }

      @organization.complete_onboarding!
      true
    end

    def persist_progress
      Onboarding::ProgressSynchronizer.call(organization: @organization)
    end

    def audit_step
      action = @step == 5 ? 'completed' : 'step_updated'
      Onboarding::Auditor.call(
        organization: @organization,
        user: @user,
        action:,
        step: @step,
        section: @step == 5 ? nil : section_key,
        metadata: { 'percentage' => Onboarding::ProgressCalculator.call(@organization)[:percentage] }
      )
    end

    def section_key
      %i[company fiscal branches terminals payments migration team][@step - 1]
    end

    def advance_step
      @organization.update!(onboarding_current_step: [@step + 1, 5].min)
    end
  end
end
