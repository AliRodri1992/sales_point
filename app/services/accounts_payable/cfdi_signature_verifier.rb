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

    # Every supported complement has an offline SAT XSLT dependency.
    # Unknown namespaces fail closed rather than silently being skipped.
    SUPPORTED_NAMESPACES = [
      'http://www.sat.gob.mx/cfd/4',
      'http://www.sat.gob.mx/TimbreFiscalDigital',
      'http://www.sat.gob.mx/ComercioExterior11',
      'http://www.sat.gob.mx/ComercioExterior20',
      'http://www.sat.gob.mx/donat',
      'http://www.sat.gob.mx/divisas',
      'http://www.sat.gob.mx/implocal',
      'http://www.sat.gob.mx/leyendasFiscales',
      'http://www.sat.gob.mx/pfic',
      'http://www.sat.gob.mx/TuristaPasajeroExtranjero',
      'http://www.sat.gob.mx/nomina12',
      'http://www.sat.gob.mx/registrofiscal',
      'http://www.sat.gob.mx/pagoenespecie',
      'http://www.sat.gob.mx/aerolineas',
      'http://www.sat.gob.mx/valesdedespensa',
      'http://www.sat.gob.mx/notariospublicos',
      'http://www.sat.gob.mx/vehiculousado',
      'http://www.sat.gob.mx/servicioparcialconstruccion',
      'http://www.sat.gob.mx/renovacionysustitucionvehiculos',
      'http://www.sat.gob.mx/certificadodestruccion',
      'http://www.sat.gob.mx/arteantiguedades',
      'http://www.sat.gob.mx/ine',
      'http://www.sat.gob.mx/iedu',
      'http://www.sat.gob.mx/ventavehiculos',
      'http://www.sat.gob.mx/detallista',
      'http://www.sat.gob.mx/EstadoDeCuentaCombustible12',
      'http://www.sat.gob.mx/ConsumoDeCombustibles11',
      'http://www.sat.gob.mx/GastosHidrocarburos10',
      'http://www.sat.gob.mx/IngresosHidrocarburos10',
      'http://www.sat.gob.mx/CartaPorte20',
      'http://www.sat.gob.mx/Pagos20',
      'http://www.sat.gob.mx/CartaPorte30',
      'http://www.sat.gob.mx/CartaPorte31',
      'http://www.sat.gob.mx/hidrocarburospetroliferos'
    ].freeze

    def self.offline_stylesheet
      File.read(STYLESHEET).gsub(%r{<xsl:include\s+href="([^"]+)"\s*/>}) do
        href = Regexp.last_match(1)
        unless href.match?(%r{\Axslt/[A-Za-z0-9_./-]+\.xslt\z}) && href.split('/').exclude?('..')
          raise ArgumentError, 'Unsafe CFDI stylesheet dependency'
        end

        file = STYLESHEET.dirname.join(href)
        raise ArgumentError, 'Missing offline SAT stylesheet dependency' unless file.file?

        source = File.read(file)
        open = source.index('>', source.index('<xsl:stylesheet')) + 1
        close = source.rindex('</xsl:stylesheet>')
        raise ArgumentError, 'Invalid offline SAT stylesheet dependency' unless close

        source[open...close]
      end
    end

    def self.validate_supported_complements!(document)
      unknown = document.xpath('//*').find do |element|
        SUPPORTED_NAMESPACES.exclude?(element.namespace&.href)
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
      stylesheet = Nokogiri::XSLT(offline_stylesheet)
      chain = stylesheet.transform(document).to_s.strip
      seal = Base64.strict_decode64(document.root['Sello'].to_s)
      return if certificate.public_key.verify(OpenSSL::Digest.new('SHA256'), seal, chain)

      raise ArgumentError, 'Invalid CFDI digital signature'
    end
  end
end
