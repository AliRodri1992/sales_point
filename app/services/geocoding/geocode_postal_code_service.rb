module Geocoding
  class GeocodePostalCodeService
    MAPBOX_URL = 'https://api.mapbox.com/geocoding/v5/mapbox.places'.freeze

    def initialize(postal_code, country = 'MX')
      @postal_code = postal_code
      @country = country
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 30.days) do
        feature = fetch_feature
        next unless feature

        build_result(feature)
      end
    end

    private

    def fetch_feature
      response = connection.get(url)
      return unless response.success?
      return if response.body.blank?

      json = JSON.parse(response.body)
      json['features']&.first
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.options.timeout = 5
        f.options.open_timeout = 2
      end
    end

    def build_result(feature)
      {
        lat: feature.dig('center', 1),
        lng: feature.dig('center', 0),
        full_address: feature['place_name'],
        relevance: feature['relevance']
      }
    end

    def url
      query = CGI.escape(postal_code_query.to_s)

      "#{MAPBOX_URL}/#{query}.json?access_token=#{mapbox_token}&limit=1"
    end

    def postal_code_query
      "#{@postal_code}, #{@country}"
    end

    def mapbox_token
      ENV.fetch('MAPBOX_TOKEN')
    end

    def log_error(type, error)
      Rails.logger.error("[GeocodePostalCodeService] #{type}: #{error.message}")
    end

    def cache_key
      "address:geocode:#{Digest::MD5.hexdigest(full_address)}"
    end
  end
end
