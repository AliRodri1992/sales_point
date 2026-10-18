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

      level = Integer(zoom).clamp(12, 18)
      path = "#{lon},#{lat},#{level},0/600x300"
      response = connection.get("#{URL}/#{path}?access_token=#{CGI.escape(token)}")
      return unless response.success? && response.body.present?

      response.body
    rescue ArgumentError, TypeError, Faraday::Error => e
      Rails.logger.warn("[MapboxStaticMap] #{e.class}")
      nil
    end

    private

    def connection
      Faraday.new do |client|
        client.options.timeout = 5
        client.options.open_timeout = 2
      end
    end
  end
end
