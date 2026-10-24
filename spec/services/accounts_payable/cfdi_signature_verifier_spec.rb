# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'
require 'tmpdir'
require 'fileutils'

RSpec.describe AccountsPayable::CfdiSignatureVerifier do
  let(:private_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:certificate) do
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = OpenSSL::BN.new('3030303031303030303030303030303030303031', 16).to_i
    certificate.subject = OpenSSL::X509::Name.parse('/CN=CFDI Test')
    certificate.issuer = certificate.subject
    certificate.public_key = private_key.public_key
    certificate.not_before = Time.utc(2020)
    certificate.not_after = Time.utc(2030)
    certificate.sign(private_key, OpenSSL::Digest.new('SHA256'))
    certificate
  end
  let(:canonical_string) do
    Nokogiri::XSLT(stylesheet).transform(Nokogiri::XML('<Comprobante/>')).to_s.strip
  end
  let(:stylesheet) do
    <<~XSLT
      <?xml version="1.0"?>
      <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:output method="text"/>
        <xsl:template match="/"><xsl:text>||4.0|2026-01-01T12:00:00||</xsl:text></xsl:template>
      </xsl:stylesheet>
    XSLT
  end

  before do
    @stylesheet_file = Tempfile.new(['sat-test', '.xslt'])
    @stylesheet_file.write(stylesheet)
    @stylesheet_file.flush
    stub_const('AccountsPayable::CfdiSignatureVerifier::STYLESHEET', Pathname.new(@stylesheet_file.path))

    @trust_file = Tempfile.new(['sat-root', '.pem'])
    @trust_file.write(certificate.to_pem)
    @trust_file.flush
    @previous_trust_store = ENV.fetch('SAT_CSD_TRUST_STORE', nil)
    ENV['SAT_CSD_TRUST_STORE'] = @trust_file.path
  end

  after do
    ENV['SAT_CSD_TRUST_STORE'] = @previous_trust_store
    @stylesheet_file&.close!
    @trust_file&.close!
  end

  def certificate_number
    certificate.serial.to_s(16).scan(/../).map { |byte| byte.to_i(16).chr }.join
  end

  def signed_xml(seal:)
    <<~XML
      <cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4" Version="4.0"
        Fecha="2026-01-01T12:00:00" NoCertificado="#{certificate_number}"
        Certificado="#{Base64.strict_encode64(certificate.to_der)}" Sello="#{seal}"/>
    XML
  end

  it 'accepts a matching RSA-SHA256 signature against the certificate' do
    seal = Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new('SHA256'), canonical_string))
    expect(described_class.call(xml: signed_xml(seal:))).to be(true)
  end

  it 'rejects an invalid digital seal' do
    invalid = Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new('SHA256'), 'altered'))
    expect { described_class.call(xml: signed_xml(seal: invalid)) }
      .to raise_error(ArgumentError, /Invalid CFDI digital signature/)
  end

  it 'rejects an issuer certificate missing from configured trust' do
    ENV['SAT_CSD_TRUST_STORE'] = '/missing/sat-roots.pem'
    seal = Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new('SHA256'), canonical_string))
    expect { described_class.call(xml: signed_xml(seal:)) }
      .to raise_error(ArgumentError, /Trusted SAT certificate bundle is missing/)
  end

  it 'fails closed when the SAT stylesheet is unavailable' do
    stub_const('AccountsPayable::CfdiSignatureVerifier::STYLESHEET', Pathname.new('/missing/sat.xslt'))
    expect { described_class.call(xml: '<xml/>') }
      .to raise_error(ArgumentError, /stylesheet is not installed/)
  end

  it 'rejects a CFDI exceeding the permitted document size' do
    expect { described_class.call(xml: 'x' * (10.megabytes + 1)) }
      .to raise_error(ArgumentError, /document exceeds 10 MB/)
  end

  it 'rejects a document without a CFDI root' do
    expect { described_class.call(xml: '<Other/>') }
      .to raise_error(ArgumentError, /Invalid CFDI 4.0/)
  end

  it 'rejects a document with an incorrect CFDI version' do
    xml = signed_xml(seal: 'AAAA').sub('Version="4.0"', 'Version="3.3"')
    expect { described_class.call(xml:) }
      .to raise_error(ArgumentError, /Invalid CFDI 4.0/)
  end

  it 'rejects a mismatched certificate serial number' do
    xml = signed_xml(seal: 'AAAA').sub("NoCertificado=\"#{certificate_number}\"", 'NoCertificado="wrong"')
    expect { described_class.call(xml:) }
      .to raise_error(ArgumentError, /Certificate number does not match/)
  end

  it 'rejects an expired certificate at the CFDI issue date' do
    xml = signed_xml(seal: 'AAAA').sub('Fecha="2026-01-01T12:00:00"', 'Fecha="2035-01-01T12:00:00"')
    expect { described_class.call(xml:) }
      .to raise_error(ArgumentError, /certificate is not valid at issue date/)
  end

  it 'rejects a missing configured SAT trust store' do
    ENV.delete('SAT_CSD_TRUST_STORE')
    expect { described_class.call(xml: signed_xml(seal: 'AAAA')) }
      .to raise_error(ArgumentError, /bundle is not configured/)
  end

  it 'rejects a certificate not trusted by the configured store' do
    @trust_file.rewind
    @trust_file.truncate(0)
    @trust_file.write('')
    @trust_file.flush
    expect { described_class.call(xml: signed_xml(seal: 'AAAA')) }
      .to raise_error(ArgumentError, /signature verification failed/)
  end

  it 'rejects a malformed certificate' do
    xml = signed_xml(seal: 'AAAA').sub(/Certificado="[^"]+"/, 'Certificado="invalid"')
    expect { described_class.call(xml:) }
      .to raise_error(ArgumentError, /signature verification failed/)
  end
  it 'rejects an empty XML document' do
    expect { described_class.call(xml: '') }
      .to raise_error(ArgumentError, /Empty document/)
  end

  it 'rejects the wrong CFDI namespace' do
    xml = signed_xml(seal: 'AAAA').sub('http://www.sat.gob.mx/cfd/4', 'urn:untrusted-cfdi')
    expect { described_class.call(xml:) }
      .to raise_error(ArgumentError, /Invalid CFDI 4.0/)
  end

  it 'rejects a comprobante without the CFDI namespace' do
    expect { described_class.call(xml: '<Comprobante Version="4.0"/>') }
      .to raise_error(ArgumentError, /Invalid CFDI 4.0/)
  end

  it 'rejects a malformed digital seal encoding' do
    xml = signed_xml(seal: 'not-base64!!')
    expect { described_class.call(xml:) }
      .to raise_error(ArgumentError, /signature verification failed/)
  end

  it 'rejects a CFDI with a missing issuance date' do
    xml = signed_xml(seal: 'AAAA').sub(/Fecha="[^"]+"/, '')

    expect { described_class.call(xml:) }
      .to raise_error(ArgumentError, /certificate is not valid at issue date/)
  end

  it 'rejects a cryptographically valid certificate without a trusted issuer' do
    store = instance_double(OpenSSL::X509::Store)
    allow(OpenSSL::X509::Store).to receive(:new).and_return(store)
    allow(store).to receive(:add_file).with(@trust_file.path)
    allow(store).to receive(:time=)
    allow(store).to receive(:verify).and_return(false)
    seal = Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new('SHA256'), canonical_string))

    expect { described_class.call(xml: signed_xml(seal:)) }
      .to raise_error(ArgumentError, /CFDI certificate is not trusted/)
  end

  it 'rejects unrecognized fiscal complements before checking the digital seal' do
    xml = signed_xml(seal: 'AAAA').sub('/>', <<~XML.strip)
      >
        <cfdi:Complemento>
          <unknown:Extra xmlns:unknown="urn:untrusted:complement"/>
        </cfdi:Complemento>
      </cfdi:Comprobante>
    XML

    expect { described_class.call(xml:) }
      .to raise_error(ArgumentError, /Unsupported CFDI complement/)
  end

  it 'compiles the bundled offline SAT stylesheet without remote includes' do
    original = Rails.root.join('config/sat/cadenaoriginal_4_0.xslt')
    contents = File.read(original)
    expect(contents).to include('<xsl:include')
    stub_const('AccountsPayable::CfdiSignatureVerifier::STYLESHEET', original)
    compiled = described_class.offline_stylesheet
    expect(compiled).not_to include('<xsl:include')
    expect { Nokogiri::XSLT(compiled) }.not_to raise_error
  end

  it 'blocks local include paths that escape the trusted SAT directory' do
    @stylesheet_file.rewind
    @stylesheet_file.truncate(0)
    @stylesheet_file.write('<xsl:include href="../untrusted.xslt"/>')
    @stylesheet_file.flush

    expect { described_class.offline_stylesheet }
      .to raise_error(ArgumentError, /Unsafe CFDI stylesheet dependency/)
  end

  it 'rejects missing offline SAT stylesheet dependencies' do
    @stylesheet_file.rewind
    @stylesheet_file.truncate(0)
    @stylesheet_file.write('<xsl:include href="xslt/missing.xslt"/>')
    @stylesheet_file.flush

    expect { described_class.offline_stylesheet }
      .to raise_error(ArgumentError, /Missing offline SAT stylesheet dependency/)
  end

  it 'rejects XSLT fragments that are malformed or contain nested includes' do
    Dir.mktmpdir('sat-cfdi') do |dir|
      root = Pathname.new(dir).join('root.xslt')
      template = Pathname.new(dir).join('xslt/dependency.xslt')
      FileUtils.mkdir_p(template.dirname)
      File.write(root, '<xsl:include href="xslt/dependency.xslt"/>')
      stub_const('AccountsPayable::CfdiSignatureVerifier::STYLESHEET', root)

      File.write(template, 'not a stylesheet')
      expect { described_class.offline_stylesheet }
        .to raise_error(ArgumentError, /Invalid offline SAT stylesheet dependency/)

      File.write(template, <<~XSLT)
        <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
          <xsl:include href="https://untrusted.example/other.xslt"/>
        </xsl:stylesheet>
      XSLT
      expect { described_class.offline_stylesheet }
        .to raise_error(ArgumentError, /Nested SAT stylesheet dependency is not allowed/)
    end
  end

  it 'rejects a CFDI with no Version attribute' do
    xml = signed_xml(seal: 'AAAA').sub('Version="4.0"', '')

    expect { described_class.call(xml:) }.to raise_error(ArgumentError, /Invalid CFDI 4.0/)
  end

  it 'rejects a CFDI containing XML elements without a known fiscal namespace' do
    xml = signed_xml(seal: 'AAAA').sub('/>', '><Unknown/></cfdi:Comprobante>')

    expect { described_class.call(xml:) }
      .to raise_error(ArgumentError, /Unsupported CFDI complement/)
  end

  it 'rejects an empty parsed XML document before processing any certificate' do
    allow(Nokogiri).to receive(:XML).and_return(Nokogiri::XML::Document.new)

    expect { described_class.send(:parse_cfdi, '<ignored/>') }
      .to raise_error(ArgumentError, /Invalid CFDI 4.0/)
  end
end
