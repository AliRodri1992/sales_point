# frozen_string_literal: true

module Landing
  class FeaturesComponent < ViewComponent::Base
    def initialize(title:, subtitle:, features:)
      super()

      @title = title
      @subtitle = subtitle
      @features = features

    end

    private

    attr_reader(
      :title,
      :subtitle,
      :features
    )
  end
end