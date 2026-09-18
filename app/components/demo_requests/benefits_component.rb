# frozen_string_literal: true

module DemoRequests
  class BenefitsComponent < ViewComponent::Base
    BENEFITS = %i[personalized resolve_questions no_commitment].freeze

    private

    attr_reader :benefits

    def initialize
      super
      @benefits = BENEFITS
    end
  end
end
