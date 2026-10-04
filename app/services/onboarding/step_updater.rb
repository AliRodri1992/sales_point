# frozen_string_literal: true

module Onboarding
  class StepUpdater
    def self.call(organization:, step:, params:)
      new(organization, step, params).call
    end

    def initialize(organization, step, params)
      @organization = organization
      @step = step
      @params = params
    end

    def call
      success = false

      ApplicationRecord.transaction do
        result = case @step
                 when 1 then update_company
                 when 2 then update_branch
                 when 3 then update_terminals
                 when 4 then update_payment
                 when 5 then complete_onboarding
                 else false
                 end

        raise ActiveRecord::Rollback unless result

        persist_progress
        advance_step unless @step == 5
        success = true
      end

      success
    rescue ActiveRecord::RecordInvalid, KeyError, ActionController::ParameterMissing
      false
    end

    private

    def complete_onboarding
      progress = Onboarding::ProgressCalculator.call(@organization)
      return false unless progress[:sections].all? { |section| section[:percentage] == 100 }

      @organization.complete_onboarding!
      true
    end

    def update_company
      organization_attributes = @params.expect(organization: %i[name tax_id business_sector currency timezone])
      settings = @organization.organization_settings.first
      return false unless settings

      @organization.update!(organization_attributes.slice(:name, :tax_id, :business_sector))
      settings.update!(
        currency: organization_attributes[:currency],
        timezone: organization_attributes[:timezone]
      )

      true
    end

    def update_branch
      branch = active_branch
      return false unless branch

      branch.update!(@params.expect(
                       branch: [
                         :name,
                         :phone,
                         { address_attributes: %i[
                           id street exterior_number interior_number neighborhood city state country postal_code
                         ] }
                       ]
                     ))
    end

    def update_terminals
      branch = active_branch
      return false unless branch

      terminals = branch.terminals.active_records.order(:id).to_a
      return false if terminals.empty?

      terminals.each_with_index do |terminal, index|
        terminal.update!(name: terminal_name(index))
      end

      true
    end

    def update_payment
      settings = @organization.organization_settings.first
      return false unless settings

      method = @params.expect(payment: [:method]).fetch(:method)
      return false unless %w[cash card qr].include?(method)

      settings.update!(payment_method: method)
      update_payment_integrations(method)
      true
    end

    def update_payment_integrations(method)
      if method == 'cash'
        deactivate_all_payment_integrations
      else
        create_or_update_payment_integration(method)
      end
    end

    def deactivate_all_payment_integrations
      @organization.payment_integrations.where(deleted_at: nil).find_each do |integration|
        integration.update!(deleted_at: Time.current, status: 'inactive')
      end
    end

    def create_or_update_payment_integration(method)
      integration = @organization.payment_integrations.find_or_initialize_by(provider: method)
      integration.update!(status: :pending, deleted_at: nil)
    end

    def active_branch
      @organization.branches.not_deleted.where(status: true).first ||
        @organization.branches.not_deleted.first
    end

    def terminal_name(index)
      @params.dig(:terminal_names, index.to_s).presence ||
        I18n.t('registration.initial_terminal_name', number: index + 1)
    end

    def persist_progress
      Onboarding::ProgressSynchronizer.call(organization: @organization)
    end

    def advance_step
      @organization.update!(onboarding_current_step: [@step + 1, 5].min)
    end
  end
end
