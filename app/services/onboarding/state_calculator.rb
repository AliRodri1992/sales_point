# frozen_string_literal: true

module Onboarding
  class StateCalculator
    def initialize(organization, step)
      @organization = organization
      @step = step
    end

    def call
      case @step
      when 1 then company_state
      when 2 then branch_state
      when 3 then terminals_state
      when 4 then payment_state
      else {}
      end
    end

    private

    def company_state
      settings = @organization.organization_settings.first

      {
        'organization' => @organization.attributes.slice('name', 'tax_id', 'business_sector'),
        'settings' => settings&.attributes&.slice('currency', 'timezone')
      }
    end

    def branch_state
      branch = @organization.branches.not_deleted.where(status: true).first ||
               @organization.branches.not_deleted.first
      return {} unless branch

      {
        'branch' => branch.attributes.slice('name', 'phone'),
        'address' => branch.address&.attributes&.slice('street', 'exterior_number', 'interior_number', 'neighborhood',
                                                       'city', 'state', 'country', 'postal_code')
      }
    end

    def terminals_state
      branch = @organization.branches.not_deleted.where(status: true).first ||
               @organization.branches.not_deleted.first
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

      integrations = @organization.payment_integrations
                                  .where(deleted_at: nil)
                                  .order(:id)
                                  .map do |integration|
        integration.attributes.slice(
          'provider', 'status'
        )
      end

      {
        'settings' => settings&.attributes&.slice('payment_method'),
        'integrations' => integrations
      }
    end
  end
end
