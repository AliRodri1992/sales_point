# frozen_string_literal: true

module Admin
  class KpiCardComponent < ViewComponent::Base
    def initialize(title:, value:, change: nil, status: nil, icon_name: nil)
      super()

      @title = title
      @value = value
      @change = change
      @status = status
      @icon_name = icon_name
    end

    private

    attr_reader :title, :value, :change, :status, :icon_name

    delegate :icon, to: :helpers
  end
end
