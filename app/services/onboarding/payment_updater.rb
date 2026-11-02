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
      unless OrganizationSetting.payment_methods.key?(method)
        settings.errors.add(:payment_method, :inclusion)
        return false
      end
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
      create_or_update_payment_integration(method) unless method == 'cash'
    end

    def create_or_update_payment_integration(method)
      integration = @organization.payment_integrations.with_deleted.find_or_initialize_by(provider: method)
      return unless integration.new_record? || integration.deleted_at.present? || integration.inactive?

      integration.update!(status: :pending, deleted_at: nil)
    end
  end
end
