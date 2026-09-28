# frozen_string_literal: true

module Landing
  class HeroComponent < ViewComponent::Base
    def initialize(badge:, title:, highlighted:, description:, primary_button_text:, primary_button_href:, secondary_button_text:, secondary_button_href:)
      super()
      @badge = badge
      @title = title
      @highlighted = highlighted
      @description = description
      @primary_button_text = primary_button_text
      @primary_button_href = primary_button_href
      @secondary_button_text = secondary_button_text
      @secondary_button_href = secondary_button_href
    end

    private

    attr_reader :badge, :title, :highlighted, :description,
                :primary_button_text, :primary_button_href,
                :secondary_button_text, :secondary_button_href
  end
end
