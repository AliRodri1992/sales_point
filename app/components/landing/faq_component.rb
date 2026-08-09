# frozen_string_literal: true

module Landing
  class FaqComponent < ViewComponent::Base
    def initialize(title:, subtitle:, questions:)
      super

      @title = title
      @subtitle = subtitle
      @questions = questions
    end

    private

    attr_reader :title, :subtitle, :questions
  end
end
