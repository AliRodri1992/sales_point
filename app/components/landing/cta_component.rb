# frozen_string_literal: true

module Landing
  class CtaComponent < ViewComponent::Base
    def initialize(title:, description:, button:)
      super

      @title = title
      @description = description
      @button = button
    end

    private

    attr_reader :title, :description, :button
  end
end
