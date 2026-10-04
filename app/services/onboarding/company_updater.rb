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

      attributes = @params.expect(organization: %i[name tax_id business_sector currency timezone])
      return false unless update_organization(attributes)
      return false unless update_settings(settings, attributes)

      true
    end

    private

    def update_organization(attributes)
      @organization.assign_attributes(attributes.slice(:name, :tax_id, :business_sector))
      @organization.save(context: :onboarding_step_1)
    end

    def update_settings(settings, attributes)
      settings.assign_attributes(currency: attributes[:currency], timezone: attributes[:timezone])
      settings.save(context: :onboarding_step_1)
    end
  end
end
