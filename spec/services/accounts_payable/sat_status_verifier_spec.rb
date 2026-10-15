# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountsPayable::SatStatusVerifier do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user) }
  let(:xml) { '<cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4" Sello="abcdefgh12345678"/>' }
  let(:invoice) do
    SupplierInvoice.create!(
      organization:, supplier:, created_by: actor, currency: supplier.currency,
      issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow,
      subtotal: 100, tax_amount: 16, total: 116, source: :cfdi, uuid: SecureRandom.uuid,
      issuer_rfc: supplier.rfc, receiver_rfc: organization.tax_id
    ).tap do |record|
      record.xml_document.attach(io: StringIO.new(xml), filename: 'invoice.xml', content_type: 'application/xml')
    end
  end
  let(:http) { instance_double(Net::HTTP) }
  let(:response) { Net::HTTPOK.new('1.1', '200', 'OK') }
  let(:sat_xml) do
    '<ConsultaResponse><CodigoEstatus>S - Correcto</CodigoEstatus><Estado>Vigente</Estado></ConsultaResponse>'
  end

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(response)
    allow(response).to receive(:body).and_return(sat_xml)
  end

  it 'queries the fixed official SAT endpoint with safe XML escaping' do
    result = described_class.call(invoice:)

    expect(result).to include(status: 'Vigente', code: 'S - Correcto')
    expect(result.fetch(:verified_at)).to be_within(5.seconds).of(Time.current)
    expect(Net::HTTP).to have_received(:start)
      .with(described_class::HOST, 443, use_ssl: true, open_timeout: 3, read_timeout: 8)
    expect(http).to have_received(:request) do |request|
      expect(request.path).to eq(described_class::PATH)
      expect(request['SOAPAction']).to eq(described_class::SOAP_ACTION)
      expect(request.body).to include('fe=12345678', '&amp;rr=', '&amp;tt=')
    end
  end

  it 'rejects a cancelled invoice' do
    allow(response).to receive(:body).and_return(sat_xml.sub('Vigente', 'Cancelado'))
    expect { described_class.call(invoice:) }.to raise_error(ArgumentError, /Cancelado/)
  end

  it 'rejects a response without a status code' do
    allow(response).to receive(:body).and_return('<ConsultaResponse><Estado>Vigente</Estado></ConsultaResponse>')
    expect { described_class.call(invoice:) }.to raise_error(ArgumentError, 'Invalid SAT response')
  end

  it 'rejects a SOAP Fault' do
    allow(response).to receive(:body).and_return('<Envelope><Fault>Unavailable</Fault></Envelope>')
    expect { described_class.call(invoice:) }.to raise_error(ArgumentError, 'Invalid SAT response')
  end

  it 'rejects a response that is too large' do
    allow(response).to receive(:body).and_return('x' * 70.kilobytes)
    expect { described_class.call(invoice:) }.to raise_error(ArgumentError, 'Invalid SAT response')
  end

  it 'blocks posting if the SAT endpoint fails' do
    allow(Net::HTTP).to receive(:start).and_raise(SocketError)

    expect { AccountsPayable::PostInvoice.call(invoice:, actor:) }
      .to raise_error(ArgumentError, /SAT status could not be verified/)
    expect(invoice.reload).to be_draft
    expect(invoice.account_payable).to be_nil
  end

  it 'requires the CFDI digital seal for verification' do
    invoice.xml_document.purge
    invoice.xml_document.attach(
      io: StringIO.new('<Comprobante />'), filename: 'unsealed.xml', content_type: 'application/xml'
    )
    expect { described_class.call(invoice:) }.to raise_error(ArgumentError, 'Missing CFDI digital seal')
  end

  it 'records successful SAT status when posting a CFDI' do
    allow(AccountsPayable::CfdiParser).to receive(:call).and_return(
      uuid: invoice.uuid, issuer_rfc: supplier.rfc, receiver_rfc: organization.tax_id,
      total: invoice.total, currency_code: invoice.currency.code
    )
    allow(AccountsPayable::CfdiSignatureVerifier).to receive(:call).and_return(true)
    payable = AccountsPayable::PostInvoice.call(invoice:, actor:)

    expect(payable.amount).to eq(116)
    expect(invoice.reload).to be_posted
    expect(invoice.sat_status).to eq('Vigente')
    expect(invoice.sat_response_code).to eq('S - Correcto')
    expect(invoice.sat_verified_at).to be_present
  end
end
