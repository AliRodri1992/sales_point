# frozen_string_literal: true

module Landing
  class TestimonialComponent < ViewComponent::Base
    def initialize(
      name:,
      company:,
      position:,
      quote:,
      avatar:
    )
      super()

      @name = name
      @company = company
      @position = position
      @quote = quote
      @avatar = avatar
    end

    private

    attr_reader :name, :company, :position, :quote, :avatar
  end
end
