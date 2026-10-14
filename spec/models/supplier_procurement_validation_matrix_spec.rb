# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier financial and purchasing relationship validation' do
  let(:organization) { create(:organization) }
  let(:foreign_organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:foreign_supplier) { create(:supplier, organization: foreign_organization) }
  let(:branch) { create(:branch, organization:, name: 'Valid Procurement Branch') }
  let(:user) { create(:user) }
  let(:product) { create(:product, organization:) }
  let(:currency) { supplier.currency }

  def invoice(attributes = {})
    SupplierInvoice.new({
      organization:, supplier:, currency:, created_by: user,
      issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow,
      subtotal: 100, total: 100
    }.merge(attributes))
  end

  def quotation(attributes = {})
    PurchaseQuotation.new({ organization:, supplier:, currency: }.merge(attributes))
  end

  def order(attributes = {})
    PurchaseOrder.new({
      organization:, branch:, supplier:, currency:, requested_by: user
    }.merge(attributes))
  end

  def credit(attributes = {})
    SupplierCreditNote.new({
      organization:, supplier:, currency:, created_by: user, total: 10, issued_on: Date.current
    }.merge(attributes))
  end

  def receipt(attributes = {})
    GoodsReceipt.new({
      organization:, branch:, purchase_order: order, received_by: user,
      received_at: Time.current, idempotency_key: SecureRandom.uuid
    }.merge(attributes))
  end

  it 'rejects a supplier invoice belonging to a different tenant' do
    record = invoice(supplier: foreign_supplier)
    record.valid?
    expect(record.errors[:supplier]).to be_present
  end

  it 'rejects a supplier invoice with a purchase order for a different supplier' do
    purchase = order(supplier: create(:supplier, organization:))
    record = invoice(purchase_order: purchase)
    record.valid?
    expect(record.errors[:purchase_order]).to be_present
  end

  it 'rejects a supplier invoice with a foreign purchase order' do
    purchase = order(organization: foreign_organization, supplier: foreign_supplier)
    record = invoice(purchase_order: purchase)
    record.valid?
    expect(record.errors[:purchase_order]).to be_present
  end

  it 'rejects credit notes for foreign suppliers' do
    record = credit(supplier: foreign_supplier)
    record.valid?
    expect(record.errors[:supplier]).to be_present
  end

  it 'rejects a credit note referenced to a different supplier invoice' do
    other = invoice(supplier: create(:supplier, organization:))
    record = credit(supplier_invoice: other)
    record.valid?
    expect(record.errors[:supplier_invoice]).to be_present
  end

  it 'rejects a credit note referencing an invoice in another tenant' do
    other = invoice(organization: foreign_organization, supplier: foreign_supplier)
    record = credit(supplier_invoice: other)
    record.valid?
    expect(record.errors[:supplier_invoice]).to be_present
  end

  it 'rejects a supplier payment with a different organization supplier' do
    payment = SupplierPayment.new(
      organization:, supplier: foreign_supplier, currency:, created_by: user,
      paid_on: Date.current, amount: 10
    )
    payment.valid?
    expect(payment.errors[:supplier]).to be_present
  end

  it 'rejects account payable linked to another supplier' do
    payable = AccountPayable.new(
      organization:, supplier: create(:supplier, organization:), supplier_invoice: invoice,
      amount: 10, due_on: Date.tomorrow
    )
    payable.valid?
    expect(payable.errors[:supplier_invoice]).to be_present
  end

  it 'rejects account payable referencing foreign organization invoice' do
    other = invoice(organization: foreign_organization, supplier: foreign_supplier)
    payable = AccountPayable.new(
      organization:, supplier:, supplier_invoice: other, amount: 10, due_on: Date.tomorrow
    )
    payable.valid?
    expect(payable.errors[:supplier_invoice]).to be_present
  end

  it 'rejects purchase quotation belonging to a different supplier organization' do
    record = quotation(supplier: foreign_supplier)
    record.valid?
    expect(record.errors[:supplier]).to be_present
  end

  it 'rejects purchase quotations originating from an unapproved request' do
    request = PurchaseRequest.new(organization:, branch:, requested_by: user, status: :draft)
    record = quotation(purchase_request: request)
    record.valid?
    expect(record.errors[:purchase_request]).to be_present
  end

  it 'rejects purchase quotation request from another tenant' do
    request = PurchaseRequest.new(
      organization: foreign_organization, branch: create(:branch, organization: foreign_organization),
      requested_by: user, status: :approved
    )
    record = quotation(purchase_request: request)
    record.valid?
    expect(record.errors[:purchase_request]).to be_present
  end

  it 'rejects purchase order for an external branch' do
    record = order(branch: create(:branch, organization: foreign_organization))
    record.valid?
    expect(record.errors[:branch]).to be_present
  end

  it 'rejects purchase order for an external supplier' do
    record = order(supplier: foreign_supplier)
    record.valid?
    expect(record.errors[:supplier]).to be_present
  end

  it 'rejects purchase order referencing unapproved request' do
    request = PurchaseRequest.new(organization:, branch:, requested_by: user)
    record = order(purchase_request: request)
    record.valid?
    expect(record.errors[:purchase_request]).to be_present
  end

  it 'rejects purchase order sourced from an unaccepted quotation' do
    record = order(purchase_quotation: quotation(status: :submitted))
    record.valid?
    expect(record.errors[:purchase_quotation]).to be_present
  end

  it 'rejects purchase order sourced from an expired quotation' do
    record = order(purchase_quotation: quotation(status: :accepted, valid_until: Date.yesterday))
    record.valid?
    expect(record.errors[:purchase_quotation]).to be_present
  end

  it 'rejects purchase order with a quotation for another supplier' do
    offer = quotation(supplier: create(:supplier, organization:), status: :accepted)
    record = order(purchase_quotation: offer)
    record.valid?
    expect(record.errors[:purchase_quotation]).to be_present
  end

  it 'rejects purchase order with a quotation for another tenant' do
    offer = quotation(organization: foreign_organization, supplier: foreign_supplier, status: :accepted)
    record = order(purchase_quotation: offer)
    record.valid?
    expect(record.errors[:purchase_quotation]).to be_present
  end

  it 'rejects an order with foreign product line' do
    record = order
    record.purchase_order_items.build(
      product: create(:product, organization: foreign_organization), quantity: 1,
      units_per_package: 1, unit_price: 10
    )
    record.valid?
    expect(record.errors[:purchase_order_items]).to be_present
  end

  it 'rejects a quotation item product from outside the organization' do
    record = PurchaseQuotationItem.new(
      purchase_quotation: quotation, product: create(:product, organization: foreign_organization),
      quantity: 2, units_per_package: 1, unit_price: 10, discount_percent: 0, lead_time_days: 1
    )
    record.valid?
    expect(record.errors[:product]).to be_present
  end

  it 'rejects a quotation item linked to a mismatched supplier offer' do
    offer = SupplierProduct.new(
      organization: foreign_organization, supplier: foreign_supplier, product:, currency:
    )
    record = PurchaseQuotationItem.new(
      purchase_quotation: quotation, product:, supplier_product: offer,
      quantity: 1, units_per_package: 1, unit_price: 10, discount_percent: 0, lead_time_days: 1
    )
    record.valid?
    expect(record.errors[:supplier_product]).to be_present
  end

  it 'rejects an order item product from another tenant' do
    record = PurchaseOrderItem.new(
      purchase_order: order, product: create(:product, organization: foreign_organization),
      quantity: 1, units_per_package: 1, unit_price: 10, discount_percent: 0, nonrecoverable_tax: 0
    )
    record.valid?
    expect(record.errors[:product]).to be_present
  end

  it 'rejects an order item connected to another supplier offer' do
    offer = SupplierProduct.new(
      organization: foreign_organization, supplier: foreign_supplier, product:, currency:
    )
    record = PurchaseOrderItem.new(
      purchase_order: order, product:, supplier_product: offer,
      quantity: 1, units_per_package: 1, unit_price: 10, discount_percent: 0, nonrecoverable_tax: 0
    )
    record.valid?
    expect(record.errors[:supplier_product]).to be_present
  end

  it 'rejects receipt belonging to a different tenant order' do
    foreign_order = order(organization: foreign_organization, supplier: foreign_supplier)
    record = receipt(purchase_order: foreign_order)
    record.valid?
    expect(record.errors[:purchase_order]).to be_present
  end

  it 'rejects a receipt with an external branch' do
    record = receipt(branch: create(:branch, organization: foreign_organization))
    record.valid?
    expect(record.errors[:branch]).to be_present
  end

  it 'rejects a receipt branch different from its order branch' do
    record = receipt(branch: create(:branch, organization:))
    record.valid?
    expect(record.errors[:branch]).to be_present
  end

  it 'rejects supplier schedule whose branch belongs to another organization' do
    schedule = SupplierSchedule.new(
      supplier:, branch: create(:branch, organization: foreign_organization),
      kind: 'visit', weekday: 1, starts_at: '10:00', ends_at: '11:00'
    )
    schedule.valid?
    expect(schedule.errors[:branch]).to be_present
  end

  it 'rejects supplier schedule whose end precedes its start' do
    schedule = SupplierSchedule.new(
      supplier:, branch:, kind: 'visit', weekday: 1, starts_at: '15:00', ends_at: '10:00'
    )
    schedule.valid?
    expect(schedule.errors[:ends_at]).to be_present
  end

  it 'rejects a second active primary contact belonging to one supplier' do
    create(:contact, :primary, contactable: supplier)
    contact = build(:contact, :primary, contactable: supplier)
    contact.valid?
    expect(contact.errors[:primary]).to be_present
  end

  it 'rejects a second active primary fiscal address belonging to one supplier' do
    first = create(:address, :primary, :fiscal, addressable: supplier)
    second = build(:address, :primary, :fiscal, addressable: supplier, country: first.country)
    second.valid?
    expect(second.errors[:primary]).to be_present
  end

  it 'does not restore contacts that were never archived' do
    contact = create(:contact, contactable: supplier)
    expect(contact.restore_safely).to be(false)
  end

  it 'does not restore addresses that were never archived' do
    address = create(:address, addressable: supplier)
    expect(address.restore_safely).to be(false)
  end

  it 'does not restore schedules that were never archived' do
    schedule = SupplierSchedule.create!(
      supplier:, branch:, kind: 'visit', weekday: 1, starts_at: '10:00', ends_at: '11:00'
    )
    expect(schedule.restore_safely).to be(false)
  end

  it 'handles missing CLABE and account numbers with a masked placeholder' do
    record = SupplierBankAccount.new
    expect(record.masked_number).to eq('••••')
  end

  it 'rejects bank data from suppliers of other organizations' do
    record = SupplierBankAccount.new(
      organization:, supplier: foreign_supplier,
      bank_name: 'Bank', holder_name: 'User', account_number: '1234567890', currency_code: 'MXN'
    )
    record.valid?
    expect(record.errors[:supplier]).to be_present
  end
end
