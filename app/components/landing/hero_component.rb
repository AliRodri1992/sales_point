# frozen_string_literal: true

module Landing
  class HeroComponent < ViewComponent::Base
    def initialize(badge:, title:, highlighted:, description:, **button_options)
      super()
      assign_content(badge:, title:, highlighted:, description:)
      assign_buttons(button_options)
    end

    private

    attr_reader :badge, :title, :highlighted, :description,
                :primary_button_text, :primary_button_href,
                :secondary_button_text, :secondary_button_href

    def assign_content(badge:, title:, highlighted:, description:)
      @badge = badge
      @title = title
      @highlighted = highlighted
      @description = description
    end

    def assign_buttons(button_options)
      @primary_button_text = button_options.fetch(:primary_button_text)
      @primary_button_href = button_options.fetch(:primary_button_href)
      @secondary_button_text = button_options.fetch(:secondary_button_text)
      @secondary_button_href = button_options.fetch(:secondary_button_href)
    end
  end
end
