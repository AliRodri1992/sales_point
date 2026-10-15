# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invoice fiscal document, purchase and cancellation integrity', type: :service do
  describe SupplierInvoice do
    let(:invoice) { described_class.new(organization_id: 1, supplier_id: 5) }

    it 'rejects supplier organizations that do not match' do
      allow(invoice).to receive(:supplier).and_return(double(organization_id: 2))
      invoice.send(:consistent_relations)
      expect(invoice.errors[:supplier]).not_to be_empty
    end

    it 'rejects a purchase order from a different supplier' do
      allow(invoice).to receive(:purchase_order)
        .and_return(double(organization_id: 1, supplier_id: 2))
      invoice.send(:consistent_relations)
      expect(invoice.errors[:purchase_order]).not_to be_empty
    end

    it 'accepts a purchase order with matching supplier and organization' do
      allow(invoice).to receive(:purchase_order)
        .and_return(double(organization_id: 1, supplier_id: 5))
      invoice.send(:consistent_relations)
      expect(invoice.errors[:purchase_order]).to be_empty
    end

    it 'skips absent document attachments' do
      invoice.send(:valid_documents)
      expect(invoice.errors[:xml_document]).to be_empty
      expect(invoice.errors[:pdf_document]).to be_empty
    end

    it 'rejects unsafe XML content types' do
      document = double(attached?: true, blob: double(content_type: 'text/html', byte_size: 12))
      allow(invoice).to receive(:xml_document).and_return(document)
      invoice.send(:valid_documents)
      expect(invoice.errors[:xml_document]).not_to be_empty
    end

    it 'rejects oversized invoice PDF files' do
      blob = double(content_type: 'application/pdf', byte_size: 11.megabytes)
      document = double(attached?: true, blob:)
      allow(invoice).to receive(:pdf_document).and_return(document)
      invoice.send(:valid_documents)
      expect(invoice.errors[:pdf_document]).not_to be_empty
    end

    it 'accepts correctly typed XML and PDF attachments within size limits' do
      xml = double(attached?: true, blob: double(content_type: 'application/xml', byte_size: 1.kilobyte))
      pdf = double(attached?: true, blob: double(content_type: 'application/pdf', byte_size: 1.kilobyte))
      allow(invoice).to receive(:xml_document).and_return(xml)
      allow(invoice).to receive(:pdf_document).and_return(pdf)
      invoice.send(:valid_documents)
      expect(invoice.errors[:xml_document]).to be_empty
      expect(invoice.errors[:pdf_document]).to be_empty
    end
  end

  describe AccountsPayable::CancelInvoice do
    it 'refuses to cancel an already cancelled invoice' do
      invoice = double(cancelled?: true)
      allow(invoice).to receive(:with_lock).and_yield
      expect { described_class.call(invoice:, actor: double) }
        .to raise_error(ArgumentError, /already cancelled/)
    end

    it 'cancels a document without any payable financial movements' do
      invoice = double(cancelled?: false, account_payable: nil, organization: double)
      allow(invoice).to receive(:with_lock).and_yield
      allow(invoice).to receive(:update!)
      allow(FinancialAuditEvent).to receive(:record!)
      expect(described_class.call(invoice:, actor: double)).to eq(invoice)
      expect(invoice).to have_received(:update!).with(hash_including(status: :cancelled))
      expect(FinancialAuditEvent).to have_received(:record!).once
    end
  end
end
