# frozen_string_literal: true

require 'digest'
require 'json'
require 'uri'

module TranslationProviders
  class LibreTranslateProvider
    PROVIDER_NAME = 'libretranslate'.freeze

    def self.provider_name
      PROVIDER_NAME
    end

    def self.configuration_version
      Digest::SHA256.hexdigest(
        {
          endpoint: endpoint,
          connect_timeout: connect_timeout,
          read_timeout: read_timeout,
          write_timeout: write_timeout,
          host_allowlist: host_allowlist
        }.to_json
      )
    end

    def initialize
      @connection = Faraday.new(url: self.class.endpoint) do |connection|
        connection.options.open_timeout = self.class.connect_timeout
        connection.options.timeout = self.class.read_timeout
        connection.options.write_timeout = self.class.write_timeout
        connection.headers['Accept'] = 'application/json'
        connection.headers['Content-Type'] = 'application/json'
      end
    end

    def translate_many(texts:, source:, target:)
      validate_language!(source)
      validate_language!(target)

      response = @connection.post('/translate') do |request|
        request.body = {
          q: texts,
          source: source,
          target: target,
          format: 'html',
          api_key: ENV['LIBRETRANSLATE_API_KEY'].presence
        }.compact.to_json
      end

      raise_error_for_status(response)

      payload = JSON.parse(response.body)
      translations = payload['translatedText']
      translations = [translations] if translations.is_a?(String)

      unless translations.is_a?(Array) && translations.length == texts.length
        raise TranslationProvider::InvalidResponseError,
              'LibreTranslate returned an invalid translation payload'
      end

      translations
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
      raise TranslationProvider::TransientError, e.message
    rescue JSON::ParserError => e
      raise TranslationProvider::InvalidResponseError, e.message
    end

    def self.endpoint
      value = ENV.fetch('LIBRETRANSLATE_URL', 'http://libretranslate:5000').strip
      uri = URI.parse(value)

      raise TranslationProvider::PermanentError, 'Invalid LibreTranslate URL' unless uri.is_a?(URI::HTTP)
      raise TranslationProvider::PermanentError, 'LibreTranslate URL cannot contain credentials' if uri.userinfo
      raise TranslationProvider::PermanentError, 'LibreTranslate URL host is not allowed' unless host_allowed?(uri)
      if Rails.env.production? && uri.scheme != 'https'
        raise TranslationProvider::PermanentError, 'LibreTranslate must use HTTPS in production'
      end

      value.sub(%r{/+$}, '')
    rescue URI::InvalidURIError => e
      raise TranslationProvider::PermanentError, e.message
    end

    def self.host_allowlist
      ENV['LIBRETRANSLATE_ALLOWED_HOSTS'].to_s.split(',').map(&:strip).reject(&:empty?)
    end

    def self.host_allowed?(uri)
      host_allowlist.presence&.include?(uri.host) || host_allowlist.blank?
    end

    def self.connect_timeout
      ENV.fetch('LIBRETRANSLATE_CONNECT_TIMEOUT', '5').to_i
    end

    def self.read_timeout
      ENV.fetch('LIBRETRANSLATE_READ_TIMEOUT', '30').to_i
    end

    def self.write_timeout
      ENV.fetch('LIBRETRANSLATE_WRITE_TIMEOUT', '30').to_i
    end

    private

    def validate_language!(code)
      return if code.present? && code.match?(/A[a-z]{2}z/i)

      raise TranslationProvider::UnsupportedLanguageError,
            "Unsupported provider language: #{code.inspect}"
    end

    def raise_error_for_status(response)
      return if response.success?

      error_class = case response.status
                    when 408, 429, 500, 502, 503, 504
                      TranslationProvider::TransientError
                    when 400, 401, 403, 422
                      TranslationProvider::PermanentError
                    else
                      TranslationProvider::Error
                    end

      raise error_class, "LibreTranslate HTTP #{response.status}: #{response.body.to_s.truncate(1_000)}"
    end
  end
end
