module Geocoding
  class MapboxValidateAddressService
    MAPBOX_URL = 'https://api.mapbox.com/geocoding/v5/mapbox.places'.freeze

    def initialize(address)
      @address = address
    end

    def call
      response = Faraday.get(url)

      json = JSON.parse(response.body)

      return false if json['features'].empty?

      feature = json['features'].first

      {
        valid: true,
        full_address: feature['place_name'],
        latitude: feature['center'][1],
        longitude: feature['center'][0],
        confidence: feature['relevance']
      }
    rescue StandardError
      { valid: false }
    end

    private

    def url
      query = CGI.escape(full_address_string)

      "#{MAPBOX_URL}/#{query}.json?access_token=#{ENV.fetch('MAPBOX_TOKEN', nil)}&limit=1"
    end

    def full_address_string
      [
        @address.street,
        @address.exterior_number,
        @address.neighborhood,
        @address.city,
        @address.state,
        @address.country,
        @address.postal_code
      ].compact.join(', ')
    end
  end
end
