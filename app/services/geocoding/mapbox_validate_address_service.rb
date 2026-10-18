# frozen_string_literal: true

module Geocoding
  class MapboxValidateAddressService
    MAPBOX_URL = 'https://api.mapbox.com/geocoding/v5/mapbox.places'

    def initialize(address)
      @address = address
    end

    def call
      return { valid: false } if token.blank?

      response = connection.get(url)
      return { valid: false } unless response.success?

      extract_response(response.body)
    rescue Faraday::Error, JSON::ParserError, TypeError, KeyError => e
      Rails.logger.warn("[MapboxAddress] #{e.class}")
      { valid: false }
    end

    private

    def extract_response(body)
      feature = JSON.parse(body).fetch('features', []).first
      feature ? build_result(feature) : { valid: false }
    end

    def build_result(feature)
      center = feature.fetch('center')
      lat = Float(center.fetch(1))
      lng = Float(center.fetch(0))
      return { valid: false } unless lat.between?(-90, 90) && lng.between?(-180, 180)

      {
        valid: true,
        full_address: feature['place_name'],
        latitude: lat, longitude: lng,
        confidence: feature['relevance']
      }
    rescue ArgumentError, IndexError
      { valid: false }
    end

    def connection
      @connection ||= Faraday.new do |client|
        client.options.timeout = 5
        client.options.open_timeout = 2
      end
    end

    def url
      query = CGI.escape(@address.geocoding_query)
      "#{MAPBOX_URL}/#{query}.json?access_token=#{CGI.escape(token)}&limit=1"
    end

    def token = ENV['MAPBOX_TOKEN'].presence
  end
end
