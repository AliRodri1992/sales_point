# frozen_string_literal: true

module Landing
  class ModulesComponent < ViewComponent::Base
    def initialize(title:, subtitle:, modules:)
      super()

      @title = title
      @subtitle = subtitle
      @modules = modules
    end

    private

    attr_reader :title, :subtitle, :modules
  end
end
