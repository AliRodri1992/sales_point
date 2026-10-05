# frozen_string_literal: true

module Onboarding
  class Requirement
    def self.call(organization:, section:)
      new(organization:, section:).call
    end

    def initialize(organization:, section:)
      @organization = organization
      @section = section.to_sym
    end

    def call
      progress = ProgressCalculator.call(@organization)
      section = progress[:sections].find { |item| item[:key] == @section }

      return { complete: true, section: @section, percentage: 100 } unless section

      {
        complete: section[:percentage] == 100,
        section: @section,
        percentage: section[:percentage]
      }
    end
  end
end
