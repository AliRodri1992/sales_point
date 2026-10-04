# frozen_string_literal: true

module Onboarding
  class StepUpdater
    def self.call(organization:, step:, params:, user:, branch: nil, settings: nil, terminals: nil)
      new(organization, step, params, user, branch, settings, terminals).call
    end

    def initialize(organization, step, params, user, branch, settings, terminals)
      @organization = organization
      @step = step
      @params = params
      @user = user
      @branch = branch
      @settings = settings
      @terminals = terminals
      @before_state = {}
      @after_state = {}
    end

    def call
      ApplicationRecord.transaction do
        @before_state = configuration_state
        result = execute_step
        return false unless result

        @after_state = configuration_state
        persist_progress
        advance_step if @step == @organization.onboarding_current_step && @step < 5
        audit_step
      end

      true
    rescue ActiveRecord::RecordInvalid, KeyError, ActionController::ParameterMissing
      false
    end

    private

    def execute_step
      case @step
      when 1 then CompanyUpdater.call(@organization, @params, settings: @settings)
      when 2 then BranchUpdater.call(@organization, @params, branch: @branch)
      when 3 then TerminalsUpdater.call(@organization, @params, terminals: @terminals)
      when 4 then PaymentUpdater.call(@organization, @params, settings: @settings)
      when 5 then complete_onboarding?
      else false
      end
    end

    def complete_onboarding?
      progress = Onboarding::ProgressCalculator.call(@organization)
      applicable_sections = progress[:sections].reject { |section| section[:status] == 'not_applicable' }
      return false unless applicable_sections.all? { |section| section[:percentage] == 100 }

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
        metadata: {
          'percentage' => Onboarding::ProgressCalculator.call(@organization)[:percentage],
          'changes' => configuration_changes
        }
      )
    end

    def configuration_state
      case @step
      when 1 then company_state
      when 2 then branch_state
      when 3 then terminals_state
      when 4 then payment_state
      else {}
      end
    end

    def company_state
      settings = @organization.organization_settings.first

      {
        'organization' => @organization.attributes.slice('name', 'tax_id', 'business_sector'),
        'settings' => settings&.attributes&.slice('currency', 'timezone')
      }
    end

    def branch_state
      branch = active_branch
      return {} unless branch

      {
        'branch' => branch.attributes.slice('name', 'phone'),
        'address' => branch.address&.attributes&.slice(
          'street',
          'exterior_number',
          'interior_number',
          'neighborhood',
          'city',
          'state',
          'country',
          'postal_code'
        )
      }
    end

    def terminals_state
      branch = active_branch
      return {} unless branch

      branch.terminals.active_records.order(:id).each_with_index.to_h do |terminal, index|
        [
          index.to_s,
          terminal.attributes.slice('name', 'code', 'status', 'branch_id')
        ]
      end
    end

    def payment_state
      settings = @organization.organization_settings.first

      {
        'settings' => settings&.attributes&.slice('payment_method'),
        'integrations' => @organization.payment_integrations
          .where(deleted_at: nil)
          .order(:id)
          .map { |integration| integration.attributes.slice('provider', 'status') }
      }
    end

    def active_branch
      @organization.branches.not_deleted.where(status: true).first ||
        @organization.branches.not_deleted.first
    end

    def configuration_changes
      diff_hash(@before_state, @after_state)
    end

    def diff_hash(before, after)
      keys = (before.keys | after.keys).sort
      keys.each_with_object({}) do |key, changes|
        before_value = before[key]
        after_value = after[key]

        if before_value.is_a?(Hash) && after_value.is_a?(Hash)
          nested = diff_hash(before_value, after_value)
          changes[key] = nested if nested.present?
        elsif before_value != after_value
          changes[key] = {
            'from' => before_value,
            'to' => after_value
          }
        end
      end
    end

    def section_key
      %i[company fiscal branches terminals payments migration team][@step - 1]
    end

    def advance_step
      @organization.update!(onboarding_current_step: [@step + 1, 5].min)
    end
  end
end
