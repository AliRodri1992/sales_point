# frozen_string_literal: true

module Onboarding
  class ProgressSynchronizer
    def self.call(organization:)
      new(organization:).call
    end

    def initialize(organization:)
      @organization = organization
    end

    def call
      progress = ProgressCalculator.call(@organization)

      onboarding_sections = progress[:sections].index_by { |section| section[:key].to_s }.transform_values do |section|
        {
          'percentage' => section[:percentage],
          'status' => section[:status]
        }
      end

      @organization.update_columns(
        onboarding_sections:,
        updated_at: Time.current
      )

      progress
    end
  end
end
