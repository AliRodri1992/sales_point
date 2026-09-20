# frozen_string_literal: true

module Landing
  class HeroComponent < ViewComponent::Base
    def initialize(attributes)
      super()

      @badge = attributes[:badge]
      @title = attributes.fetch(:title)
      @highlighted = attributes.fetch(:highlighted)
      @description = attributes.fetch(:description)
      @image = attributes.fetch(:image)
      @primary_button = attributes.fetch(:primary_button)
      @secondary_button = attributes.fetch(:secondary_button)
      @statistics = attributes.fetch(:statistics)
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
