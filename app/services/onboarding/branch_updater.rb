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

      branch.update(
        @params.expect(
          branch: [
            :name,
            :phone,
            { address_attributes: %i[
              id street exterior_number interior_number neighborhood city state country postal_code
            ] }
          ]
        )
      )
    end
  end
end
