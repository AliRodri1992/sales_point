# frozen_string_literal: true

module Geocoding
  class MapboxStaticMapService
    URL = 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static'.freeze

    def call(latitude:, longitude:)
      token = ENV['MAPBOX_TOKEN'].presence
      return unless token

      lat = Float(latitude)
      lon = Float(longitude)
      return unless lat.between?(-90, 90) && lon.between?(-180, 180)

      path = "#{lon},#{lat},15,0/600x300"
      response = Faraday.new { |c| c.options.timeout = 5; c.options.open_timeout = 2 }
                        .get("#{URL}/#{path}?access_token=#{CGI.escape(token)}")
      return unless response.success? && response.body.present?

      response.body
    rescue ArgumentError, TypeError, Faraday::Error => e
      Rails.logger.warn("[MapboxStaticMap] #{e.class}")
      nil
    end
  end
end
