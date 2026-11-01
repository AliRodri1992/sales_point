# frozen_string_literal: true

module Geocoding
  class MapboxStaticMapService
    URL = 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static'

    def call(latitude:, longitude:, zoom: 15)
      token = ENV['MAPBOX_TOKEN'].presence
      return unless token

      lat = Float(latitude)
      lon = Float(longitude)
      return unless lat.between?(-90, 90) && lon.between?(-180, 180)

      map_path = "#{lon},#{lat},#{Integer(zoom).clamp(12, 18)},0/600x300"
      load_map(map_path, token)
    rescue ArgumentError, TypeError, Faraday::Error => e
      Rails.logger.warn("[MapboxStaticMap] #{e.class}")
      nil
    end

    private

    def load_map(map_path, token)
      key = Digest::SHA256.hexdigest("#{token}:#{map_path}")
      Rails.cache.fetch("mapbox:static:#{key}", expires_in: 6.hours, skip_nil: true) do
        response = connection.get("#{URL}/#{map_path}?access_token=#{CGI.escape(token)}")
        response.body if response.success? && response.body.present?
      end
    end

    def connection
      Faraday.new do |client|
        client.options.timeout = 5
        client.options.open_timeout = 2
      end
    end
  end
end
