# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountsPayable::PostInvoice do
  describe '.validate_cfdi_identity!' do
    let(:document) { double('XML attachment', download: '<xml/>') }
    let(:supplier) { double('Supplier', rfc: 'AAA010101AAA') }
    let(:organization) { double('Organization', tax_id: 'BBB010101BBB') }
    let(:currency) { double('Currency', code: 'MXN') }
    let(:invoice) do
      double('Invoice', xml_document: document, uuid: 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE',
                        supplier:, organization:, currency:, total: 150.to_d)
    end
    let(:parsed) do
      { uuid: invoice.uuid, issuer_rfc: supplier.rfc, receiver_rfc: organization.tax_id,
        total: invoice.total, currency_code: currency.code }
    end

    before { allow(AccountsPayable::CfdiParser).to receive(:call).and_return(parsed) }

    it 'accepts an XML matching the invoice and fiscal identities' do
      expect { described_class.validate_cfdi_identity!(invoice) }.not_to raise_error
    end

    it 'rejects a changed invoice amount' do
      parsed[:total] = 200.to_d

      expect { described_class.validate_cfdi_identity!(invoice) }
        .to raise_error(ArgumentError, /CFDI total does not match/)
    end

    it 'rejects mismatched fiscal identity' do
      parsed[:receiver_rfc] = 'CCC010101CCC'

      expect { described_class.validate_cfdi_identity!(invoice) }
        .to raise_error(ArgumentError, /CFDI receiver_rfc does not match/)
    end

    it 'rejects a different currency' do
      parsed[:currency_code] = 'USD'

      expect { described_class.validate_cfdi_identity!(invoice) }
        .to raise_error(ArgumentError, /CFDI currency differs/)
    end
  end
end
