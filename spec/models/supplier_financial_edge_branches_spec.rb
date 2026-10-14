# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier procurement edge-case branches' do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:other_supplier) { create(:supplier, organization:) }
  let(:currency) { supplier.currency }
  let(:user) { create(:user) }

  def credit(supplier_record: supplier, organization_record: organization)
    SupplierCreditNote.new(
      organization: organization_record, supplier: supplier_record, currency:, created_by: user,
      issued_on: Date.current, total: 20
    )
  end

  def invoice(supplier_record: supplier, organization_record: organization, status: :draft)
    SupplierInvoice.new(
      organization: organization_record, supplier: supplier_record, currency:, created_by: user,
      subtotal: 20, total: 20, issued_on: Date.current, received_on: Date.current,
      due_on: Date.tomorrow, status:
    )
  end

  it 'rejects a receipt line whose accepted and damaged quantities exceed delivered' do
    item = GoodsReceiptItem.new(delivered_quantity: 3, accepted_quantity: 3, damaged_quantity: 1)
    item.valid?
    expect(item.errors[:accepted_quantity]).to be_present
  end

  it 'does not run receipt arithmetic on missing quantity values' do
    item = GoodsReceiptItem.new(delivered_quantity: nil, accepted_quantity: 1, damaged_quantity: 0)
    item.valid?
    expect(item.errors[:delivered_quantity]).to be_present
  end

  it 'rejects a receipt line belonging to another purchase order' do
    receipt = GoodsReceipt.new(purchase_order_id: 100)
    line = PurchaseOrderItem.new(purchase_order_id: 101)
    item = GoodsReceiptItem.new(
      goods_receipt: receipt, purchase_order_item: line,
      delivered_quantity: 1, accepted_quantity: 1, damaged_quantity: 0
    )
    item.valid?
    expect(item.errors[:purchase_order_item]).to be_present
  end

  it 'rejects a returned line from a different goods receipt' do
    returned = PurchaseReturn.new(goods_receipt_id: 10)
    line = GoodsReceiptItem.new(goods_receipt_id: 12)
    item = PurchaseReturnItem.new(purchase_return: returned, goods_receipt_item: line, quantity: 1)
    item.valid?
    expect(item.errors[:goods_receipt_item]).to be_present
  end

  it 'rejects a purchase request line from a foreign organization' do
    request = PurchaseRequest.new(organization:, requested_by: user)
    line = PurchaseRequestItem.new(
      purchase_request: request, product: create(:product, organization: other_organization), quantity: 1
    )
    line.valid?
    expect(line.errors[:product]).to be_present
  end

  it 'rejects supplier credit allocation for a different supplier debt' do
    payable = AccountPayable.new(
      organization:, supplier: other_supplier, supplier_invoice: invoice(supplier_record: other_supplier),
      amount: 20, due_on: Date.tomorrow
    )
    item = SupplierCreditAllocation.new(
      organization:, supplier_credit_note: credit, account_payable: payable, amount: 10
    )
    item.valid?
    expect(item.errors[:account_payable]).to be_present
  end

  it 'rejects supplier credit allocation for another organization debt' do
    another = create(:supplier, organization: other_organization)
    payable = AccountPayable.new(
      organization: other_organization, supplier: another,
      supplier_invoice: invoice(supplier_record: another, organization_record: other_organization),
      amount: 20, due_on: Date.tomorrow
    )
    item = SupplierCreditAllocation.new(
      organization:, supplier_credit_note: credit, account_payable: payable, amount: 10
    )
    item.valid?
    expect(item.errors[:account_payable]).to be_present
  end

  it 'rejects a credit note related to a return for another supplier' do
    order = PurchaseOrder.new(organization:, supplier: other_supplier)
    goods_receipt = GoodsReceipt.new(organization:, purchase_order: order)
    returned = PurchaseReturn.new(organization:, goods_receipt:)
    item = credit
    item.purchase_return = returned
    item.valid?
    expect(item.errors[:purchase_return]).to be_present
  end

  it 'rejects a credit note related to a foreign organization return' do
    returned = PurchaseReturn.new(organization: other_organization)
    item = credit
    item.purchase_return = returned
    item.valid?
    expect(item.errors[:purchase_return]).to be_present
  end

  it 'normalizes supplier contact emails, names and optional fields' do
    contact = build(:contact, contactable: supplier, name: '  Seller  ',
                              email: '  SUPPLIER@EXAMPLE.COM ', notes: '  Note  ')
    contact.valid?
    expect(contact).to have_attributes(name: 'Seller', email: 'supplier@example.com', notes: 'Note')
  end

  it 'rejects invalid supplier contact phone numbers after normalization' do
    contact = build(:contact, contactable: supplier, phone: 'xyz12')
    contact.valid?
    expect(contact.errors[:phone]).to be_present
  end

  it 'allows empty optional supplier contact phone values' do
    contact = build(:contact, contactable: supplier, phone: '', mobile_phone: '')
    contact.valid?
    expect(contact.errors[:phone]).to be_empty
    expect(contact.errors[:mobile_phone]).to be_empty
  end

  it 'refuses to restore a contact that would duplicate a primary' do
    create(:contact, :primary, contactable: supplier)
    archived = create(:contact, :primary, :deleted, contactable: supplier)
    expect(archived.restore_safely).to be(false)
    expect(archived.reload.deleted_at).to be_present
  end

  it 'refuses to restore an address that duplicates another primary' do
    create(:address, :fiscal, :primary, addressable: supplier)
    archived = create(:address, :fiscal, :primary, :deleted, addressable: supplier)
    expect(archived.restore_safely).to be(false)
    expect(archived.reload.deleted_at).to be_present
  end

  it 'standardizes bank account currency and whitespace' do
    account = SupplierBankAccount.new(
      organization:, supplier:, bank_name: 'Local bank', holder_name: 'Vendor',
      account_number: ' 1234 5678 ', currency_code: 'mxn'
    )
    account.valid?
    expect(account).to have_attributes(account_number: '12345678', currency_code: 'MXN')
    expect(account.masked_number).to include('5678')
  end

  it 'rejects bank account with invalid currency length' do
    account = SupplierBankAccount.new(
      organization:, supplier:, bank_name: 'Local bank', holder_name: 'Vendor',
      account_number: '12345678', currency_code: 'PESO'
    )
    account.valid?
    expect(account.errors[:currency_code]).to be_present
  end

  it 'rejects invalid CLABE checksum' do
    account = SupplierBankAccount.new(
      organization:, supplier:, bank_name: 'Local bank', holder_name: 'Vendor',
      clabe: '032180000118359710', currency_code: 'MXN'
    )
    account.valid?
    expect(account.errors[:clabe]).to be_present
  end

  it 'normalizes ISO country codes without changing the display name' do
    country = Country.new(
      name: 'Testland', iso_alpha2: '  mx ', iso_alpha3: ' mex ', iso_numeric: ' 484 '
    )
    country.valid?
    expect(country).to have_attributes(iso_alpha2: 'MX', iso_alpha3: 'MEX', iso_numeric: '484')
  end

  it 'preserves missing ISO code validation errors' do
    country = Country.new(name: 'Example')
    country.valid?
    expect(country.errors[:iso_alpha2]).to be_present
    expect(country.errors[:iso_alpha3]).to be_present
    expect(country.errors[:iso_numeric]).to be_present
  end

  it 'recognizes overdue and unsettled accounts payable for active invoices' do
    record = AccountPayable.new(
      organization:, supplier:, supplier_invoice: invoice(status: :posted),
      amount: 20, due_on: Date.yesterday
    )
    expect(record).to be_overdue
    expect(record).not_to be_settled
  end

  it 'treats cancelled-invoice account payables as having no outstanding balance' do
    record = AccountPayable.new(
      organization:, supplier:, supplier_invoice: invoice(status: :cancelled),
      amount: 20, due_on: Date.yesterday
    )
    expect(record.balance).to eq(0)
    expect(record).not_to be_overdue
    expect(record).not_to be_settled
  end
end
