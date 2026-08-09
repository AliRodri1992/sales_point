# frozen_string_literal: true

module Authentication
  class ThemeSelectorComponent < ViewComponent::Base
    def initialize(themes:, current_theme:)
      super

      @themes = themes
      @current_theme = current_theme
    end

    private

    attr_reader :themes, :current_theme
  end
end