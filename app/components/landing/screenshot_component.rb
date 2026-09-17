# frozen_string_literal: true

module Landing
  class ScreenshotComponent < ViewComponent::Base
    def initialize(title:, description:, image:)
      super()

      @title = title
      @description = description
      @image = image
    end

    private

    attr_reader :title,
                :description,
                :image
  end
end
