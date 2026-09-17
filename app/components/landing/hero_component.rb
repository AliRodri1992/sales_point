# frozen_string_literal: true

module Landing
  class HeroComponent < ViewComponent::Base
    def initialize(badge:,
                   title:, highlighted:,
                   description:, image:,
                   primary_button:,
                   secondary_button:,
                   statistics:)

      super()

      @badge = badge
      @title = title
      @highlighted = highlighted
      @description = description
      @image = image
      @primary_button = primary_button
      @secondary_button = secondary_button
      @statistics = statistics
    end

    private

    attr_reader(
      :badge,
      :title,
      :highlighted,
      :description,
      :image,
      :primary_button,
      :secondary_button,
      :statistics
    )
  end
end