# frozen_string_literal: true

module Suppliers
  # Looks up public postal-code data, never a complete personal address.
  # Postal suggestions are optional; failures never block manual entry.
  class MexicanPostalLookup
    PROVIDER = ENV.fetch('SEPOMEX_API_URL', 'https://sepomex.kurenn.dev').freeze
    ZIP_FORMAT = /\A\d{5}\z/
    CACHE_DURATION = 1.day

    def initialize(postal_code)
      @postal_code = postal_code.to_s
    end

    def call
      return unless ZIP_FORMAT.match?(@postal_code)

      Rails.cache.fetch("suppliers:mx_postal:#{@postal_code}", expires_in: CACHE_DURATION, skip_nil: true) do
        lookup
      end
    end

    private

    def lookup
      response = connection.get('/api/v1/zip_codes', zip_code: @postal_code, per_page: 200)
      return unless response.success?

      format_suggestions(JSON.parse(response.body).fetch('zip_codes', []))
    rescue Faraday::Error, JSON::ParserError, TypeError, KeyError => e
      Rails.logger.warn("Mexican postal lookup unavailable: #{e.class}")
      nil
    end

    def format_suggestions(rows)
      entries = rows.select { |row| row['d_codigo'] == @postal_code }
      return { found: false, neighborhoods: [] } if entries.empty?

      {
        found: true,
        state: entries.first['d_estado'],
        municipality: entries.first['d_mnpio'],
        neighborhoods: entries.filter_map { |row| row['d_asenta'].presence }.uniq.sort
      }
    end

    def connection
      @connection ||= Faraday.new(url: PROVIDER) do |client|
        client.options.timeout = 4
        client.options.open_timeout = 2
      end
    end
  end
end
