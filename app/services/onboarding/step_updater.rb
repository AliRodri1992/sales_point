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
      case @step
      when 1 then update_company
      when 2 then update_branch?
      when 3 then update_terminals?
      when 4 then update_payment?
      else false
      end
    rescue ActiveRecord::RecordInvalid, KeyError, ActionController::ParameterMissing
      false
    end

    private

    def update_company
      @organization.update(@params.expect(organization: %i[name tax_id business_sector]))
    end

    def update_branch?
      branch = @organization.branches.not_deleted.where(status: true).first ||
               @organization.branches.not_deleted.first
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

    def update_terminals?
      branch = @organization.branches.not_deleted.where(status: true).first ||
               @organization.branches.not_deleted.first
      return false unless branch

      terminals = branch.terminals.active_records.order(:id).to_a
      return false if terminals.empty?

      ActiveRecord::Base.transaction do
        terminals.each_with_index do |terminal, index|
          terminal.update!(name: terminal_name(index))
        end
      end

      true
    end

    def update_payment?
      settings = @organization.organization_settings.first
      return false unless settings

      method = @params.expect(payment: [:method]).fetch(:method)
      return false unless %w[cash card qr].include?(method)

      ActiveRecord::Base.transaction do
        settings.update!(payment_method: method)
        update_payment_integrations(method)
      end

      true
    end

    def update_existing_terminals(terminals, desired)
      terminals.first(desired).each_with_index do |terminal, index|
        terminal.update!(name: terminal_name(index), code: terminal_code(index))
      end
    end

    def deactivate_extra_terminals(terminals, desired)
      terminals.drop(desired).each do |terminal|
        terminal.update!(deleted_at: Time.current, status: :inactive)
      end
    end

    def create_new_terminals(branch, desired, existing_count)
      (existing_count...desired).each do |index|
        Terminal.create!(
          branch:,
          name: terminal_name(index),
          code: terminal_code(index),
          status: :active
        )
      end
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

    def terminal_name(index)
      @params.dig(:terminal_names, index.to_s).presence ||
        I18n.t('registration.initial_terminal_name', number: index + 1)
    end

  end
end
