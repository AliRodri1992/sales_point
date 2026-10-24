# frozen_string_literal: true

require 'base64'
require 'openssl'

module AccountsPayable
  # Validate the issuer seal against the SAT's trusted XSLT and configured CSD trust anchors.
  # An XSLT installation and trusted SAT certificates are mandatory; neither is downloaded at runtime.
  class CfdiSignatureVerifier
    STYLESHEET = Rails.root.join('config/sat/cadenaoriginal_4_0.xslt')

    def self.call(xml:)
      require_stylesheet!

      raise ArgumentError, 'CFDI document exceeds 10 MB' if xml.bytesize > 10.megabytes

      document = parse_cfdi(xml)
      validate_supported_complements!(document)
      certificate = parse_certificate(document.root)
      verify_certificate_date!(certificate, document.root)
      verify_certificate_number!(certificate, document.root)
      verify_certificate_trust!(certificate, document.root)
      verify_seal!(document, certificate)
      true
    rescue OpenSSL::OpenSSLError, ArgumentError, Nokogiri::XML::SyntaxError,
           Nokogiri::XSLT::SyntaxError, TypeError => e
      raise ArgumentError, "CFDI signature verification failed: #{e.message}"
    end

    def self.require_stylesheet!
      return if STYLESHEET.file?

      raise ArgumentError, 'CFDI stylesheet is not installed'
    end

    def self.parse_cfdi(xml)
      document = Nokogiri::XML(xml) { |options| options.strict.nonet }
      root = document.root
      valid = root&.name == 'Comprobante' &&
              root&.namespace&.href == AccountsPayable::CfdiParser::CFDI_NS &&
              root&.[]('Version') == '4.0'
      raise ArgumentError, 'Invalid CFDI 4.0' unless valid

      document
    end

    # The bundled stylesheet includes only the core CFDI and Pagos 2.0 templates.
    # Reject other namespaces so an unknown complemento cannot be omitted from a
    # seemingly valid cadena and inadvertently pass issuer-signature verification.
    SUPPORTED_NAMESPACES = [
      AccountsPayable::CfdiParser::CFDI_NS,
      'http://www.sat.gob.mx/TimbreFiscalDigital',
      'http://www.sat.gob.mx/Pagos20'
    ].freeze

    def self.validate_supported_complements!(document)
      unknown = document.xpath('//*').find do |element|
        !SUPPORTED_NAMESPACES.include?(element.namespace&.href)
      end
      return unless unknown

      raise ArgumentError, "Unsupported CFDI complement: #{unknown.name}"
    end

    def self.parse_certificate(root)
      OpenSSL::X509::Certificate.new(Base64.strict_decode64(root['Certificado'].to_s))
    end

    def self.verify_certificate_date!(certificate, root)
      issued_at = Time.zone.parse(root['Fecha'].to_s)
      return if issued_at&.between?(certificate.not_before, certificate.not_after)

      raise ArgumentError, 'CFDI certificate is not valid at issue date'
    end

    def self.verify_certificate_number!(certificate, root)
      number = certificate.serial.to_s(16).scan(/../).map { |byte| byte.to_i(16).chr }.join
      return if number == root['NoCertificado']

      raise ArgumentError, 'Certificate number does not match CFDI'
    end

    def self.verify_certificate_trust!(certificate, root)
      bundle = ENV.fetch('SAT_CSD_TRUST_STORE', nil)
      raise ArgumentError, 'Trusted SAT certificate bundle is not configured' if bundle.to_s.empty?

      raise ArgumentError, 'Trusted SAT certificate bundle is missing' unless File.file?(bundle)

      verify_trusted_certificate!(certificate, root, bundle)
    end

    def self.verify_trusted_certificate!(certificate, root, bundle)
      store = OpenSSL::X509::Store.new
      store.add_file(bundle)
      store.time = Time.zone.parse(root['Fecha'].to_s)
      raise ArgumentError, 'CFDI certificate is not trusted' unless store.verify(certificate)
    end

    def self.verify_seal!(document, certificate)
      stylesheet = Nokogiri::XSLT(File.read(STYLESHEET))
      chain = stylesheet.transform(document).to_s.strip
      seal = Base64.strict_decode64(document.root['Sello'].to_s)
      return if certificate.public_key.verify(OpenSSL::Digest.new('SHA256'), seal, chain)

      raise ArgumentError, 'Invalid CFDI digital signature'
    end
  end
end
