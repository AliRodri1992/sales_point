# frozen_string_literal: true

module Landing
  class TestimonialComponent < ViewComponent::Base
    def initialize(name:, company:, quote:, position: nil, avatar: nil)
      super()
      @name = name
      @company = company
      @position = position
      @quote = quote
      @avatar = avatar
    end

    private

    attr_reader :name, :company, :position, :quote, :avatar

    def initials
      name.split.pluck(0).first(2).join.upcase
    end
  end
end
