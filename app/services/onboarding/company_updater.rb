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
      return false unless @organization.update(attributes.slice(:name, :tax_id, :business_sector))
      return false unless settings.update(currency: attributes[:currency], timezone: attributes[:timezone])

      true
    end
  end
end
