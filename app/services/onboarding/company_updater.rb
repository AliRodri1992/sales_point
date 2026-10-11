# frozen_string_literal: true

module Onboarding
  class CompanyUpdater
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

      attributes = @params.expect(organization: %i[name tax_id business_sector base_currency_id timezone])
      return false unless update_organization(attributes)
      return false unless update_settings(settings, attributes)

      true
    end

    private

    def update_organization(attributes)
      currency = Currency.active.find_by(id: attributes[:base_currency_id])
      unless currency
        @organization.errors.add(:base_currency, :invalid)
        return false
      end

      @organization.assign_attributes(attributes.slice(:name, :tax_id, :business_sector))
      @organization.base_currency = currency
      @organization.save!(context: :onboardingstep1)
    end

    def update_settings(settings, attributes)
      settings.assign_attributes(currency: @organization.base_currency.code, timezone: attributes[:timezone])
      settings.save!(context: :onboardingstep1)
    end
  end
end
