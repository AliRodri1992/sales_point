# frozen_string_literal: true

module Authentication
  class LanguageSelectorComponent < ViewComponent::Base
    def initialize(
      languages:,
      current_language:,
      hover: :brand
    )
      super()
      @languages = languages
      @current_language = current_language
      @hover = hover
    end

    private

    attr_reader :languages,
                :current_language,
                :hover

    def hover_class
      hover == :blue ? 'language-option-blue' : 'language-option-brand'
    end
  end
end
