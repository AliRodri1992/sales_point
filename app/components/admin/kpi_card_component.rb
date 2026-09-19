# frozen_string_literal: true

module Admin
  class KpiCardComponent < ViewComponent::Base
    def initialize(title:, value:, change: nil, status: nil, icon: nil)
      super()

      @title = title
      @value = value
      @change = change
      @status = status
      @icon = icon
    end

    private

    attr_reader :title, :value, :change, :status, :icon
  end
end
