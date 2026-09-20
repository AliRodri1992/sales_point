# frozen_string_literal: true

module Landing
  class FeatureCardComponent < ViewComponent::Base
    def initialize(icon:, title:, description:, color: :primary)
      super()
      @icon = icon
      @title = title
      @description = description
      @color = color
    end

    private

    attr_reader(
      :icon,
      :title,
      :description,
      :color
    )
  end
end
