require 'net/http'
require 'openssl'
require 'base64'
require 'json'

module Incidents
  class Github
    REPOSITORY = 'AliRodri1992/sales_point'
    SETTINGS = %w[INCIDENT_GITHUB_APP_ID INCIDENT_GITHUB_INSTALLATION_ID INCIDENT_GITHUB_PRIVATE_KEY].freeze

    def self.configured?
      SETTINGS.all? { |key| ENV[key].present? }
    end

    def initialize
      now = Time.now.to_i
      header = encode({ alg: 'RS256', typ: 'JWT' }.to_json)
      claims = encode({ iat: now - 60, exp: now + 540, iss: ENV.fetch(SETTINGS.first) }.to_json)
      data = "#{header}.#{claims}"
      key = OpenSSL::PKey::RSA.new(ENV.fetch(SETTINGS.last).gsub('\\n', "\n"))
      jwt = "#{data}.#{encode(key.sign('SHA256', data))}"
      installation = Integer(ENV.fetch(SETTINGS.second))
      @token = request(:post, "/app/installations/#{installation}/access_tokens", jwt,
                       { repositories: ['sales_point'], permissions: { issues: 'write' } }).fetch('token')
    end

    def existing(folio)
      query = URI.encode_www_form(q: "repo:#{REPOSITORY} is:issue in:title #{folio}")
      request(:get, "/search/issues?#{query}", @token).fetch('items').find { |item| item['title'].start_with?("[#{folio}]") }
    end

    def create(incident)
      # The repository receives a neutral summary. Customer text and evidence stay in Delta POS.
      title = "[#{incident.folio}] #{incident.affected_module.presence || 'Delta POS'}"
      body = "Folio: #{incident.folio}\nMódulo: #{incident.affected_module}\nPantalla: #{incident.affected_screen}"
      if ENV['DELTA_POS_URL'].present?
        path = Rails.application.routes.url_helpers.admin_incident_path(incident)
        body += "\n\n#{ENV.fetch('DELTA_POS_URL').delete_suffix('/')}#{path}"
      end
      request(:post, "/repos/#{REPOSITORY}/issues", @token, { title: title, body: body })
    end

    private

    def encode(value)
      Base64.urlsafe_encode64(value, padding: false)
    end

    def request(method, path, token, payload = nil)
      uri = URI("https://api.github.com#{path}")
      message = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri)
      message['Authorization'] = "Bearer #{token}"
      message['Accept'] = 'application/vnd.github+json'
      message['User-Agent'] = 'DeltaPOS-Incidents'
      message['Content-Type'] = 'application/json'
      message.body = payload.to_json if payload
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 12) { |http| http.request(message) }
      raise IOError, "GitHub HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
