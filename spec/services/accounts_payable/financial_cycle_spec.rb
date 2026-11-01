# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier financial lifecycle' do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }
  let(:currency) { supplier.currency }

  def invoice_for(amount = 100)
    SupplierInvoice.create!(
      organization:, supplier:, currency:, created_by: user,
      issued_on: Date.current, received_on: Date.current, due_on: Date.current + 10.days,
      subtotal: amount, total: amount, tax_amount: 0, discount: 0
    )
  end

  def payment_for(amount)
    SupplierPayment.create!(
      organization:, supplier:, currency:, created_by: user,
      paid_on: Date.current, amount:
    )
  end

  it 'creates one payable when the invoice is posted' do
    invoice = invoice_for

    payable = AccountsPayable::PostInvoice.call(invoice:, actor: user)

    expect(payable).to have_attributes(amount: 100, supplier:)
    expect(invoice.reload).to be_posted
    expect { AccountsPayable::PostInvoice.call(invoice:, actor: user) }.to raise_error(ArgumentError)
    expect(invoice.account_payable).to eq(payable)
  end

  it 'handles partial payments, credit notes, and reversal without losing history' do
    invoice = invoice_for(200)
    payable = AccountsPayable::PostInvoice.call(invoice:, actor: user)
    payment = payment_for(70)

    AccountsPayable::ApplyPayment.call(payment:, allocations: [{ account_payable_id: payable.id, amount: '70' }],
                                       actor: user)
    expect(payable.reload.balance).to eq(130)

    credit = SupplierCreditNote.create!(
      organization:, supplier:, currency:, created_by: user, issued_on: Date.current,
      total: 30, status: :posted
    )
    AccountsPayable::ApplyCredit.call(credit_note: credit, account_payable: payable, amount: '30', actor: user)
    expect(payable.reload.balance).to eq(100)

    AccountsPayable::ReversePayment.call(payment:, actor: user)
    expect(payment.reload).to be_reversed
    expect(payable.reload.balance).to eq(170)
    expect(FinancialAuditEvent.where(organization:).pluck(:event))
      .to include('invoice.posted', 'payment.posted', 'credit.applied', 'payment.reversed')
  end

  it 'rejects overpayment and preserves all balances' do
    invoice = invoice_for(50)
    payable = AccountsPayable::PostInvoice.call(invoice:, actor: user)
    payment = payment_for(60)

    expect do
      AccountsPayable::ApplyPayment.call(
        payment:, allocations: [{ account_payable_id: payable.id, amount: '60' }], actor: user
      )
    end.to raise_error(ArgumentError, 'Payment exceeds open balance')

    expect(payable.reload.balance).to eq(50)
    expect(payment.reload).to be_draft
    expect(payment.supplier_payment_allocations.count).to eq(0)
  end

  it 'rejects cross-organization payment allocations' do
    other_supplier = create(:supplier, organization: create(:organization))
    invoice = SupplierInvoice.create!(
      organization: other_supplier.organization, supplier: other_supplier,
      currency: other_supplier.currency, created_by: user, issued_on: Date.current,
      received_on: Date.current, due_on: Date.tomorrow, total: 20
    )
    payable = AccountsPayable::PostInvoice.call(invoice:, actor: user)
    payment = payment_for(20)

    expect do
      AccountsPayable::ApplyPayment.call(
        payment:, allocations: [{ account_payable_id: payable.id, amount: '20' }], actor: user
      )
    end.to raise_error(ArgumentError, 'Unknown payable')
  end

  it 'reconciles open amounts independently by currency' do
    invoice = invoice_for(123)
    AccountsPayable::PostInvoice.call(invoice:, actor: user)

    result = AccountsPayable::Reconcile.call(supplier:)

    expect(result.fetch(currency.code)).to include(total: 123, pending: 123, invoices: 1)
  end
end
