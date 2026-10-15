# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'

RSpec.describe AccountsPayable::CfdiSignatureVerifier do
  let(:private_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:certificate) do
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = 1
    certificate.subject = OpenSSL::X509::Name.parse('/CN=CFDI Test')
    certificate.issuer = certificate.subject
    certificate.public_key = private_key.public_key
    certificate.not_before = Time.utc(2020)
    certificate.not_after = Time.utc(2030)
    certificate.sign(private_key, OpenSSL::Digest::SHA256.new)
    certificate
  end
  let(:canonical_string) { '||4.0|2026-01-01T12:00:00||' }
  let(:stylesheet) do
    <<~XSLT
      <?xml version="1.0"?>
      <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:output method="text"/>
        <xsl:template match="/"><xsl:text>||4.0|2026-01-01T12:00:00||</xsl:text></xsl:template>
      </xsl:stylesheet>
    XSLT
  end

  around do |example|
    Tempfile.create(['sat-test', '.xslt']) do |file|
      file.write(stylesheet)
      file.flush
      stub_const('AccountsPayable::CfdiSignatureVerifier::STYLESHEET', Pathname.new(file.path))
      example.run
    end
  end

  def signed_xml(seal:)
    <<~XML
      <cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4" Version="4.0"
        Fecha="2026-01-01T12:00:00" NoCertificado="#{certificate.serial.to_s(16).scan(/../).map { |b| b.to_i(16).chr }.join}"
        Certificado="#{Base64.strict_encode64(certificate.to_der)}" Sello="#{seal}"/>
    XML
  end

  it 'accepts a matching RSA-SHA256 signature against the certificate' do
    seal = Base64.strict_encode64(private_key.sign(OpenSSL::Digest::SHA256.new, canonical_string))
    expect(described_class.call(xml: signed_xml(seal:))).to be(true)
  end

  it 'rejects an invalid digital seal' do
    invalid = Base64.strict_encode64(private_key.sign(OpenSSL::Digest::SHA256.new, 'altered'))
    expect { described_class.call(xml: signed_xml(seal: invalid)) }
      .to raise_error(ArgumentError, /Invalid CFDI digital signature/)
  end

  it 'fails closed when the SAT stylesheet is unavailable' do
    stub_const('AccountsPayable::CfdiSignatureVerifier::STYLESHEET', Pathname.new('/missing/sat.xslt'))
    expect { described_class.call(xml: '<xml/>') }
      .to raise_error(ArgumentError, /stylesheet is not installed/)
  end
end
