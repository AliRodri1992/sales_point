# frozen_string_literal: true

module Onboarding
  class BranchUpdater
    def self.call(organization, params, branch: nil)
      new(organization, params, branch).call
    end

    def initialize(organization, params, branch)
      @organization = organization
      @params = params
      @branch = branch
    end

    def call
      branch = @branch ||
               @organization.branches.not_deleted.where(status: true).first ||
               @organization.branches.not_deleted.first
      return false unless branch

      address_attrs = %i[id street exterior_number interior_number neighborhood city state country_id postal_code]
      phone_attrs = %i[id number country_code kind label extension primary whatsapp_enabled _destroy]
      attributes = @params.expect(branch: [:name, { phones_attributes: phone_attrs, address_attributes: address_attrs }])

      branch.assign_attributes(attributes)
      return false unless branch.save!(context: :onboardingstep2)

      address = branch.address
      return true unless address

      address.save!(context: :onboardingstep2)
    end
  end
end
