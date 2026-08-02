# frozen_string_literal: true

module Authentication
  class LanguageSelectorComponent < ViewComponent::Base
    def initialize(
      languages:,
      current_language:
    )
      @languages = languages
      @current_language = current_language
    end

    private

    attr_reader :languages,
                :current_language
  end
end
