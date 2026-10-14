# frozen_string_literal: true

require 'net/http'
require 'cgi'

module AccountsPayable
  # Checks the official SAT ConsultaCFDI status for an already parsed CFDI.
  # This is an online status check, not local XML-signature verification.
  class SatStatusVerifier
    HOST = 'consultaqr.facturaelectronica.sat.gob.mx'
    PATH = '/ConsultaCFDIService.svc'
    SOAP_ACTION = 'http://tempuri.org/IConsultaCFDIService/Consulta'

    def self.call(invoice:)
      new(invoice:).call
    end

    def initialize(invoice:)
      @invoice = invoice
    end

    def call
      expression = build_expression
      response = Net::HTTP.start(HOST, 443, use_ssl: true, open_timeout: 3, read_timeout: 8) do |http|
        request = Net::HTTP::Post.new(PATH)
        request['Content-Type'] = 'text/xml; charset=utf-8'
        request['Accept'] = 'text/xml'
        request['SOAPAction'] = SOAP_ACTION
        request.body = soap_request(expression)
        http.request(request)
      end
      raise ArgumentError, 'SAT service is unavailable' unless response.is_a?(Net::HTTPSuccess)

      parse_response(response.body)
    rescue IOError, SocketError, Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError => e
      raise ArgumentError, "SAT status could not be verified: #{e.class}"
    end

    private

    def build_expression
      raise ArgumentError, 'Missing CFDI XML' unless @invoice.xml_document.attached?

      {
        re: @invoice.issuer_rfc,
        rr: @invoice.receiver_rfc,
        tt: format('%.6f', @invoice.total),
        id: @invoice.uuid,
        fe: digital_seal_suffix
      }.map { |key, value| "#{key}=#{value}" }.join('&').prepend('?')
    rescue Nokogiri::XML::SyntaxError
      raise ArgumentError, 'Invalid CFDI XML'
    end

    def digital_seal_suffix
      document = Nokogiri::XML(@invoice.xml_document.download) { |options| options.strict.nonet }
      seal = document.root&.[]('Sello').to_s
      raise ArgumentError, 'Missing CFDI digital seal' if seal.length < 8

      seal.last(8)
    end

    def soap_request(expression)
      <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body>
            <Consulta xmlns="http://tempuri.org/">
              <expresionImpresa>#{CGI.escapeHTML(expression)}</expresionImpresa>
            </Consulta>
          </s:Body>
        </s:Envelope>
      XML
    end

    def parse_response(xml)
      document = valid_sat_document(xml)
      status = sat_value(document, 'Estado')
      code = sat_value(document, 'CodigoEstatus')
      raise ArgumentError, 'Invalid SAT response' if status.blank? || code.blank?
      raise ArgumentError, "CFDI not valid according to SAT: #{status}" unless status == 'Vigente'

      { status:, code:, verified_at: Time.current }
    rescue Nokogiri::XML::SyntaxError
      raise ArgumentError, 'Invalid SAT response'
    end

    def valid_sat_document(xml)
      raise ArgumentError, 'Invalid SAT response' if xml.blank? || xml.bytesize > 64.kilobytes

      document = Nokogiri::XML(xml) { |options| options.strict.nonet }
      raise ArgumentError, 'Invalid SAT response' if document.at_xpath('//*[local-name()="Fault"]')

      document
    end

    def sat_value(document, name)
      document.at_xpath("//*[local-name()='#{name}']")&.text&.strip
    end
  end
end
