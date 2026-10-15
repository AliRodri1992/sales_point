# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invoice posting and supplier bank disclosure boundaries', type: :service do
  describe AccountsPayable::PostInvoice do
    it 'rejects an already posted invoice' do
      invoice = double(draft?: false)
      expect { described_class.validate_invoice!(invoice) }
        .to raise_error(ArgumentError, /already processed/)
    end

    it 'rejects a non-positive invoice' do
      invoice = double(draft?: true, total: 0.to_d)
      expect { described_class.validate_invoice!(invoice) }
        .to raise_error(ArgumentError, /total must be positive/)
    end

    it 'rejects CFDI invoices without an XML attachment' do
      invoice = double(draft?: true, total: 1.to_d, cfdi?: true,
                       xml_document: double(attached?: false))
      expect { described_class.validate_invoice!(invoice) }
        .to raise_error(ArgumentError, /CFDI XML is required/)
    end

    it 'permits manual invoices with valid totals' do
      invoice = double(draft?: true, total: 1.to_d, cfdi?: false)
      expect { described_class.validate_invoice!(invoice) }.not_to raise_error
    end

    it 'skips component comparison for manual invoices without a subtotal' do
      invoice = double(subtotal: 0.to_d, manual?: true)
      expect { described_class.validate_amounts!(invoice) }.not_to raise_error
    end

    it 'accepts a correct subtotal, taxes and discount reconciliation' do
      invoice = double(subtotal: 100.to_d, manual?: false, discount: 5.to_d,
                       tax_amount: 15.to_d, total: 110.to_d)
      expect { described_class.validate_amounts!(invoice) }.not_to raise_error
    end

    it 'rejects a mismatched invoice total' do
      invoice = double(subtotal: 100.to_d, manual?: false, discount: 0.to_d,
                       tax_amount: 16.to_d, total: 120.to_d)
      expect { described_class.validate_amounts!(invoice) }
        .to raise_error(ArgumentError, /does not match components/)
    end

    it 'does not generate SAT fields for manual invoices' do
      expect(described_class.sat_attributes(nil)).to eq({})
    end

    it 'preserves SAT fields for verified CFDI documents' do
      timestamp = Time.current
      verification = { status: 'Vigente', code: 'S - Correcto', verified_at: timestamp }
      expect(described_class.sat_attributes(verification))
        .to include(sat_status: 'Vigente', sat_response_code: 'S - Correcto', sat_verified_at: timestamp)
    end
  end

  describe SupplierBankAccount do
    it 'rejects an unauthorized sensitive bank data disclosure' do
      account = described_class.new
      allow(Pundit).to receive(:policy).and_return(double(reveal?: false))
      expect { account.reveal!(actor: double) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'records authorized disclosures in the financial audit trail' do
      account = described_class.new
      actor = double('Actor')
      allow(Pundit).to receive(:policy).and_return(double(reveal?: true))
      allow(FinancialAuditEvent).to receive(:record!)
      expect(account.reveal!(actor:)).to include(account_number: nil, clabe: nil)
      expect(FinancialAuditEvent).to have_received(:record!).with(
        hash_including(event: 'bank_account.revealed', actor:)
      )
    end
  end
end
