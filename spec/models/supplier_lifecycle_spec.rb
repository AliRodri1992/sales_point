# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierLifecycle, type: :model do
  let(:supplier) { build(:supplier) }

  def set_balances(orders: false, drafts: false, payables: false)
    allow(supplier).to receive(:purchase_orders).and_return(double(exists?: orders))
    allow(supplier).to receive(:supplier_invoices).and_return(double(exists?: drafts))
    outstanding = double(exists?: payables)
    allow(supplier).to receive(:account_payables).and_return(double(with_positive_balance: outstanding))
  end

  def preferred_product(organization:, supplier:)
    product = create(:product, organization:)
    SupplierProduct.create!(
      organization:, supplier:, product:, currency: supplier.currency,
      presentation_name: 'Box', units_per_package: 12, purchase_price: 120
    )
    product.update!(preferred_supplier: supplier)
    product
  end

  it 'permits archiving a supplier without open orders, draft invoices or outstanding balances' do
    set_balances
    expect(supplier.archivable?).to be(true)
  end

  it 'blocks archive if an order is still open' do
    set_balances(orders: true)
    expect(supplier.archivable?).to be(false)
    expect(supplier.errors[:base]).to include(I18n.t('admin.suppliers.lifecycle.open_orders'))
  end

  it 'blocks archive if the supplier has draft invoices' do
    set_balances(drafts: true)
    expect(supplier.archivable?).to be(false)
    expect(supplier.errors[:base]).to include(I18n.t('admin.suppliers.lifecycle.draft_invoices'))
  end

  it 'blocks archive if financial liabilities remain outstanding' do
    set_balances(payables: true)
    expect(supplier.archivable?).to be(false)
    expect(supplier.errors[:base]).to include(I18n.t('admin.suppliers.lifecycle.outstanding_payables'))
  end

  it 'clears a preferred supplier when the supplier becomes inactive' do
    organization = create(:organization)
    unavailable = create(:supplier, organization:)
    product = preferred_product(organization:, supplier: unavailable)

    unavailable.update!(status: :inactive)

    expect(product.reload.preferred_supplier).to be_nil
  end

  it 'clears preference when the supplier is archived without changing its active status' do
    organization = create(:organization)
    unavailable = create(:supplier, organization:)
    product = preferred_product(organization:, supplier: unavailable)

    unavailable.update!(deleted_at: Time.current)

    expect(product.reload.preferred_supplier).to be_nil
  end

  it 'does not alter preferences while editing an available supplier' do
    organization = create(:organization)
    available = create(:supplier, organization:)
    product = preferred_product(organization:, supplier: available)

    available.update!(notes: 'Historical trade terms')

    expect(product.reload.preferred_supplier).to eq(available)
  end
end
