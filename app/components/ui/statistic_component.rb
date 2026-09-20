# frozen_string_literal: true

module Ui
  class StatisticComponent < ViewComponent::Base
    def initialize(
      number:,
      label:,
      icon: nil
    )
      super()
      @number = number
      @label = label
      @icon = icon
    end

    private

    attr_reader :number,
                :label,
                :icon
  end
end
