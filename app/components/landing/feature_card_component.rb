# frozen_string_literal: true

module Landing
  class FeatureCardComponent < ViewComponent::Base
    def initialize(icon:, title:, description:)
      super()
      @icon = icon
      @title = title
      @description = description

    end

    private

    attr_reader(
      :icon,
      :title,
      :description
    )
  end
end