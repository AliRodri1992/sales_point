# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Accounts payable financial safeguards' do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:currency) { supplier.currency }
  let(:actor) { create(:user) }

  def invoice_for(supplier_record: supplier, total: 100, source: :manual, subtotal: total)
    SupplierInvoice.create!(
      organization:, supplier: supplier_record, currency:, created_by: actor,
      issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow,
      total:, subtotal:, source:
    )
  end

  def payment_for(supplier_record: supplier, amount: 20, currency_record: currency)
    SupplierPayment.create!(
      organization:, supplier: supplier_record, currency: currency_record, created_by: actor,
      paid_on: Date.current, amount:
    )
  end

  def payable_for
    AccountsPayable::PostInvoice.call(invoice: invoice_for, actor:)
  end

  it 'does not permit reversing a payment that has not been posted' do
    draft = payment_for

    expect { AccountsPayable::ReversePayment.call(payment: draft, actor:) }
      .to raise_error(ArgumentError, 'Only posted payments can be reversed')
    expect(draft.reload).to be_draft
  end

  it 'rejects audit records assigned to a different organization' do
    payment = payment_for
    other_organization = create(:organization)

    expect do
      FinancialAuditEvent.record!(
        organization: other_organization, actor:, event: 'payment.test', subject: payment
      )
    end.to raise_error(ArgumentError, /Cross-organization/)
  end

  it 'prevents negative reconciliation balances even if ledger data becomes inconsistent' do
    entry = double('payable', amount: 10.to_d, paid_amount: 11.to_d, credited_amount: 0.to_d)

    expect { AccountsPayable::Reconcile.reconcile_currency([entry]) }
      .to raise_error(ArgumentError, /negative balance/)
  end

  it 'allows manual invoice posting without a separately captured subtotal' do
    manual = invoice_for(total: 30, subtotal: 0)

    payable = AccountsPayable::PostInvoice.call(invoice: manual, actor:)

    expect(payable.amount).to eq(30)
    expect(manual.reload).to be_posted
  end

  it 'rejects a CFDI invoice when its required XML has not been attached' do
    cfdi = invoice_for(source: :cfdi)

    expect { AccountsPayable::PostInvoice.validate_invoice!(cfdi) }
      .to raise_error(ArgumentError, 'CFDI XML is required')
  end

  it 'rejects allocating a payment to a different supplier within the same organization' do
    debt = payable_for
    other_supplier = create(:supplier, organization:)
    payment = payment_for(supplier_record: other_supplier)

    expect do
      AccountsPayable::ApplyPayment.call(
        payment:, allocations: [{ account_payable_id: debt.id, amount: 20 }], actor:
      )
    end.to raise_error(ArgumentError, 'Different supplier or currency')
    expect(payment.reload).to be_draft
  end

  it 'rejects a payment with a blank allocation list' do
    payment = payment_for

    expect do
      AccountsPayable::ApplyPayment.call(payment:, allocations: [], actor:)
    end.to raise_error(ArgumentError, 'Allocation list cannot be empty')
  end

  it 'rejects a second reversal of the same payment' do
    debt = payable_for
    payment = payment_for
    AccountsPayable::ApplyPayment.call(
      payment:, allocations: [{ account_payable_id: debt.id, amount: 20 }], actor:
    )
    AccountsPayable::ReversePayment.call(payment:, actor:)

    expect { AccountsPayable::ReversePayment.call(payment:, actor:) }
      .to raise_error(ArgumentError, 'Only posted payments can be reversed')
  end

  it 'rejects credits associated with another suppliers payable at the model layer' do
    debt = payable_for
    unrelated_supplier = create(:supplier, organization:)
    credit = SupplierCreditNote.create!(
      organization:, supplier: unrelated_supplier, currency:, created_by: actor,
      issued_on: Date.current, total: 10
    )
    allocation = SupplierCreditAllocation.new(
      organization:, supplier_credit_note: credit, account_payable: debt, amount: 10
    )

    expect(allocation).not_to be_valid
    expect(allocation.errors[:account_payable]).to be_present
  end

  it 'rejects payment allocations whose payable belongs to another supplier' do
    debt = payable_for
    unrelated_supplier = create(:supplier, organization:)
    payment = payment_for(supplier_record: unrelated_supplier)
    allocation = SupplierPaymentAllocation.new(
      organization:, supplier_payment: payment, account_payable: debt, amount: 10
    )

    expect(allocation).not_to be_valid
    expect(allocation.errors[:account_payable]).to be_present
  end

  it 'rejects a supplier invoice linked to another suppliers purchase order' do
    branch = create(:branch, organization:)
    unrelated_supplier = create(:supplier, organization:)
    purchase_order = PurchaseOrder.create!(
      organization:, supplier: unrelated_supplier, branch:, currency:,
      requested_by: actor
    )
    invalid_invoice = invoice_for
    invalid_invoice.purchase_order = purchase_order

    expect(invalid_invoice).not_to be_valid
    expect(invalid_invoice.errors[:purchase_order]).to be_present
  end

  it 'rejects an invalid bank account identifier even when the account association is missing' do
    payment = payment_for
    payment.supplier_bank_account_id = -1

    expect(payment).not_to be_valid
    expect(payment.errors[:supplier_bank_account]).to be_present
  end

  it 'rejects a payment associated with a supplier from another organization' do
    payment = payment_for
    payment.supplier = create(:supplier, organization: create(:organization))

    expect(payment).not_to be_valid
    expect(payment.errors[:supplier]).to be_present
  end
end
