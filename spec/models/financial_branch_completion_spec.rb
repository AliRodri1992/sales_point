# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Financial model edge decisions' do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:currency) { supplier.currency }
  let(:actor) { create(:user) }

  def draft_invoice(supplier_record: supplier)
    SupplierInvoice.new(
      organization:, supplier: supplier_record, currency:, created_by: actor,
      issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow,
      subtotal: 100, total: 100
    )
  end

  it 'rejects invoices referencing a supplier from another organization' do
    invoice = draft_invoice(supplier_record: create(:supplier, organization: create(:organization)))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:supplier]).to be_present
  end

  it 'rejects purchase orders from a different supplier, even within the same organization' do
    other_supplier = create(:supplier, organization:)
    order = PurchaseOrder.create!(
      organization:, supplier: other_supplier, branch: create(:branch, organization:),
      currency:, requested_by: actor
    )
    invoice = draft_invoice
    invoice.purchase_order = order

    expect(invoice).not_to be_valid
    expect(invoice.errors[:purchase_order]).to be_present
  end

  it 'permits an invoice connected to an order for its supplier' do
    order = PurchaseOrder.create!(
      organization:, supplier:, branch: create(:branch, organization:),
      currency:, requested_by: actor
    )
    invoice = draft_invoice
    invoice.purchase_order = order

    expect(invoice).to be_valid
  end

  it 'rejects an attachment with the wrong PDF content type' do
    invoice = draft_invoice
    invoice.pdf_document.attach(io: StringIO.new('not a pdf'), filename: 'invalid.txt', content_type: 'text/plain')

    expect(invoice).not_to be_valid
    expect(invoice.errors[:pdf_document]).to be_present
  end

  it 'accepts an invoice PDF with the expected content type' do
    invoice = draft_invoice
    invoice.pdf_document.attach(io: StringIO.new('%PDF sample'), filename: 'invoice.pdf',
                                content_type: 'application/pdf')

    expect(invoice).to be_valid
  end

  it 'rejects payment against a foreign organization supplier' do
    payment = SupplierPayment.new(
      organization:, supplier: create(:supplier, organization: create(:organization)),
      currency:, created_by: actor, paid_on: Date.current, amount: 10
    )

    expect(payment).not_to be_valid
    expect(payment.errors[:supplier]).to be_present
  end

  it 'rejects payable referencing an invoice from a different supplier' do
    invoice = draft_invoice
    invoice.save!
    another_supplier = create(:supplier, organization:)
    payable = AccountPayable.new(
      organization:, supplier: another_supplier, supplier_invoice: invoice,
      amount: invoice.total, due_on: invoice.due_on
    )

    expect(payable).not_to be_valid
    expect(payable.errors[:supplier_invoice]).to be_present
  end

  it 'rejects a cross-organization financial audit record' do
    invoice = draft_invoice(supplier_record: create(:supplier, organization: create(:organization)))
    invoice.organization = invoice.supplier.organization
    invoice.save!

    expect do
      FinancialAuditEvent.record!(
        organization:, actor:, event: 'invoice.changed', subject: invoice
      )
    end.to raise_error(ArgumentError, /Cross-organization/)
  end

  it 'attaches an uploaded PDF during invoice preparation' do
    upload = Rack::Test::UploadedFile.new(
      StringIO.new('%PDF example'), 'application/pdf', original_filename: 'receipt.pdf'
    )
    invoice = draft_invoice
    result = AccountsPayable::PrepareInvoice.call(
      invoice:, organization:, attributes: { supplier_id: supplier.id, pdf_document: upload }
    )

    expect(result.pdf_document).to be_attached
    expect(result.pdf_document.blob.filename.to_s).to eq('receipt.pdf')
  end

  it 'denies anonymous requests to see supplier financial data' do
    expect(FinancialPolicy.new(nil, draft_invoice).index?).to be false
  end

  it 'restricts financial access when an authenticated user lacks membership' do
    expect(FinancialPolicy.new(actor, draft_invoice).create?).to be false
  end

  it 'denies a member without a financial permission' do
    create(:organization_membership, organization:, user: actor)

    expect(FinancialPolicy.new(actor, draft_invoice).index?).to be false
  end

  it 'returns no financial rows to an anonymous policy scope' do
    expect(FinancialPolicy::Scope.new(nil, SupplierInvoice.all).resolve).to be_empty
  end

  it 'returns no supplier accounts to an anonymous bank-account scope' do
    expect(SupplierBankAccountPolicy::Scope.new(nil, SupplierBankAccount.all).resolve).to be_empty
  end
end
