# frozen_string_literal: true

module Landing
  class CtaComponent < ViewComponent::Base
    def initialize(title:, description:, button_text:, button_href:)
      super()
      @title = title
      @description = description
      @button_text = button_text
      @button_href = button_href
    end

    private

    attr_reader :title, :description, :button_text, :button_href
  end
end
