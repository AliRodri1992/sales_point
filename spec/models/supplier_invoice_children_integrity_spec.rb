# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier invoice child financial integrity', type: :model do
  let(:draft_invoice) { instance_double(SupplierInvoice, draft?: true) }
  let(:posted_invoice) { instance_double(SupplierInvoice, draft?: false) }

  describe SupplierInvoiceLine do
    it 'allows editing a draft invoice line' do
      line = described_class.new
      allow(line).to receive(:supplier_invoice).and_return(draft_invoice)
      line.send(:invoice_must_be_draft)
      expect(line.errors[:base]).to be_empty
    end

    it 'rejects editing a posted invoice line' do
      line = described_class.new
      allow(line).to receive(:supplier_invoice).and_return(posted_invoice)
      line.send(:invoice_must_be_draft)
      expect(line.errors[:base]).to include('Invoice is not editable')
    end

    it 'allows destruction of draft invoice lines' do
      line = described_class.new
      allow(line).to receive(:supplier_invoice).and_return(draft_invoice)
      expect { line.send(:invoice_must_be_draft_for_destroy) }.not_to throw_symbol(:abort)
    end

    it 'blocks destruction of posted invoice lines' do
      line = described_class.new
      allow(line).to receive(:supplier_invoice).and_return(posted_invoice)
      expect { line.send(:invoice_must_be_draft_for_destroy) }.to throw_symbol(:abort)
    end
  end

  describe SupplierInvoiceReceipt do
    it 'allows editing draft invoice receipt associations' do
      receipt = described_class.new
      allow(receipt).to receive(:supplier_invoice).and_return(draft_invoice)
      receipt.send(:invoice_must_be_draft)
      expect(receipt.errors[:base]).to be_empty
    end

    it 'rejects editing posted invoice receipt associations' do
      receipt = described_class.new
      allow(receipt).to receive(:supplier_invoice).and_return(posted_invoice)
      receipt.send(:invoice_must_be_draft)
      expect(receipt.errors[:base]).to include('Invoice is not editable')
    end

    it 'allows destruction of draft invoice receipt associations' do
      receipt = described_class.new
      allow(receipt).to receive(:supplier_invoice).and_return(draft_invoice)
      expect { receipt.send(:invoice_must_be_draft_for_destroy) }.not_to throw_symbol(:abort)
    end

    it 'blocks destruction of posted invoice receipt associations' do
      receipt = described_class.new
      allow(receipt).to receive(:supplier_invoice).and_return(posted_invoice)
      expect { receipt.send(:invoice_must_be_draft_for_destroy) }.to throw_symbol(:abort)
    end
  end
end
