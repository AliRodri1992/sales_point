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
end
