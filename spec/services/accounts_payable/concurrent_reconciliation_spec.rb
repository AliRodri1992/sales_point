# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Accounts payable concurrent reconciliation', type: :model, concurrent_db: true do
  self.use_transactional_tests = false

  let!(:organization) { create(:organization) }
  let!(:currency) { create(:currency) }
  let!(:supplier) { create(:supplier, organization:, currency:) }
  let!(:actor) { create(:user) }
  let!(:invoice) do
    SupplierInvoice.create!(organization:, supplier:, currency:, created_by: actor,
                            issued_on: Date.current, received_on: Date.current,
                            due_on: Date.current + 14.days, total: 100, status: :posted)
  end
  let!(:payable) do
    AccountPayable.create!(organization:, supplier:, supplier_invoice: invoice,
                           amount: 100, due_on: invoice.due_on)
  end

  def payment
    SupplierPayment.create!(organization:, supplier:, currency:, created_by: actor,
                            paid_on: Date.current, amount: 70)
  end

  it 'never allows two concurrent payments to over-allocate the same payable' do
    payments = Array.new(2) { payment }
    gate = Queue.new
    threads = payments.map do |entry|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            AccountsPayable::ApplyPayment.call(
              payment: entry, allocations: [{ account_payable_id: payable.id, amount: '70' }], actor:
            )
            :posted
          rescue ArgumentError, ActiveRecord::RecordInvalid
            :rejected
          end
        end
      end
    end
    2.times { gate << true }
    expect(threads.map(&:value).sort).to eq(%i[posted rejected])
    expect(payable.reload.balance).to eq(30.to_d)
  ensure
    threads&.each(&:join)
  end

  it 'prevents two credits from exceeding a shared payable balance' do
    credits = Array.new(2) do
      SupplierCreditNote.create!(organization:, supplier:, currency:, created_by: actor,
                                 issued_on: Date.current, total: 70, status: :posted)
    end
    gate = Queue.new
    threads = credits.map do |entry|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            AccountsPayable::ApplyCredit.call(credit_note: entry, account_payable: payable,
                                              amount: '70', actor:)
            :applied
          rescue ArgumentError, ActiveRecord::RecordInvalid
            :rejected
          end
        end
      end
    end
    2.times { gate << true }
    expect(threads.map(&:value).sort).to eq(%i[applied rejected])
    expect(payable.reload.balance).to eq(30.to_d)
  ensure
    threads&.each { |thread| thread.join if thread.alive? }
  end

  it 'does not allow cancelling a posted invoice after a payment is allocated' do
    entry = payment
    AccountsPayable::ApplyPayment.call(
      payment: entry, allocations: [{ account_payable_id: payable.id, amount: '70' }], actor:
    )
    expect { AccountsPayable::CancelInvoice.call(invoice: invoice.reload, actor:) }
      .to raise_error(ArgumentError, /financial movements/)
    expect(invoice.reload).to be_posted
  end

  it 'prevents a payment and a credit from over-allocating the same payable' do
    entry = payment
    credit = SupplierCreditNote.create!(organization:, supplier:, currency:, created_by: actor,
                                        issued_on: Date.current, total: 70, status: :posted)
    gate = Queue.new
    operations = [
      lambda do
        AccountsPayable::ApplyPayment.call(
          payment: entry, allocations: [{ account_payable_id: payable.id, amount: '70' }], actor:
        )
      end,
      lambda do
        AccountsPayable::ApplyCredit.call(credit_note: credit, account_payable: payable,
                                          amount: '70', actor:)
      end
    ]
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            operation.call
            :applied
          rescue ArgumentError, ActiveRecord::RecordInvalid
            :rejected
          end
        end
      end
    end
    2.times { gate << true }
    expect(threads.map(&:value).sort).to eq(%i[applied rejected])
    expect(payable.reload.balance).to eq(30.to_d)
  ensure
    threads&.each { |thread| thread.join if thread.alive? }
  end

  it 'rejects a second reversal of the same payment' do
    entry = payment
    AccountsPayable::ApplyPayment.call(
      payment: entry, allocations: [{ account_payable_id: payable.id, amount: '70' }], actor:
    )
    AccountsPayable::ReversePayment.call(payment: entry.reload, actor:)
    expect { AccountsPayable::ReversePayment.call(payment: entry.reload, actor:) }
      .to raise_error(ArgumentError, /Only posted payments/)
    expect(payable.reload.balance).to eq(100.to_d)
  end

  it 'does not persist a partial payment when an allocation exceeds the balance' do
    entry = payment
    expect do
      AccountsPayable::ApplyPayment.call(
        payment: entry, allocations: [{ account_payable_id: payable.id, amount: '100' }], actor:
      )
    end.to raise_error(ArgumentError, /Payment amount differs/)
    expect(entry.reload).to be_draft
    expect(entry.supplier_payment_allocations.count).to eq(0)
    expect(payable.reload.balance).to eq(100.to_d)
  end

  it 'restores available balance after reversing a posted payment' do
    entry = payment
    AccountsPayable::ApplyPayment.call(
      payment: entry, allocations: [{ account_payable_id: payable.id, amount: '70' }], actor:
    )
    AccountsPayable::ReversePayment.call(payment: entry.reload, actor:)

    expect(entry.reload).to be_reversed
    expect(payable.reload.balance).to eq(100.to_d)
  end
end
