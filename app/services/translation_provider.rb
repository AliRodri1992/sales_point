# frozen_string_literal: true

module TranslationProvider
  class Error < StandardError; end
  class TransientError < Error; end
  class PermanentError < Error; end
  class InvalidResponseError < PermanentError; end
  class UnsupportedLanguageError < PermanentError; end
end
