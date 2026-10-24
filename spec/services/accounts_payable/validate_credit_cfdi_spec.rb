# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountsPayable::ValidateCreditCfdi do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:credit) do
    SupplierCreditNote.new(organization:, supplier:, currency: supplier.currency,
                           uuid: 'D43A75A7-832E-4C41-8175-977713154DBA', total: 125)
  end

  it 'rejects issuer, receiver, UUID and currency mismatches without trusting the signature' do
    credit.xml_document.attach(io: StringIO.new('<Credit/>'), filename: 'credit.xml',
                               content_type: 'application/xml')
    data = { uuid: credit.uuid, issuer_rfc: supplier.rfc, receiver_rfc: organization.tax_id,
             total: 125.to_d, currency_code: supplier.currency.code }
    allow(AccountsPayable::CfdiParser).to receive(:call).and_return(data.merge(issuer_rfc: 'FOREIGN'))

    expect(AccountsPayable::CfdiSignatureVerifier).not_to receive(:call)
    expect { described_class.call(credit_note: credit) }
      .to raise_error(ArgumentError, /issuer_rfc mismatch/)
  end
end
