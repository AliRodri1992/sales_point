# frozen_string_literal: true

module Onboarding
  class PaymentUpdater
    def self.call(organization, params, settings: nil)
      new(organization, params, settings).call
    end

    def initialize(organization, params, settings)
      @organization = organization
      @params = params
      @settings = settings
    end

    def call
      settings = @settings || @organization.organization_settings.first
      return false unless settings

      method = @params.expect(payment: [:method]).fetch(:method)
      return false unless assign_payment_method(settings, method)

      update_payment_integrations(method)
      true
    end

    private

    def assign_payment_method(settings, method)
      settings.payment_method = method
      settings.save!(context: :onboardingstep4)
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
      integration = @organization.payment_integrations.with_deleted.find_or_initialize_by(provider: method)
      integration.update!(status: :pending, deleted_at: nil)
    end
  end
end
