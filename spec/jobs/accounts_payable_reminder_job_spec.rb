# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountsPayableReminderJob do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:recipient) { create(:user) }

  def create_payable(due_on)
    invoice = SupplierInvoice.create!(
      organization:, supplier:, currency: supplier.currency, created_by: recipient,
      issued_on: Date.current, received_on: Date.current, due_on:,
      total: 100, subtotal: 100
    )
    AccountsPayable::PostInvoice.call(invoice:, actor: recipient)
  end

  before do
    create(:organization_membership, organization:, user: recipient)
    create(:user_role, user: recipient, system_role: create(:system_role, :system, code: 'administrator'))
    allow(recipient).to receive(:broadcast_notifications_refresh)
  end

  it 'delivers an account payable notification once per recipient and day' do
    payable = create_payable(Date.current)

    expect { described_class.perform_now(Date.current) }.to change(FinancialReminderDelivery, :count).by(1)
    expect(recipient.reload.notifications.count).to eq(1)
    expect(FinancialReminderDelivery.last.account_payable).to eq(payable)

    expect { described_class.perform_now(Date.current) }.not_to change(FinancialReminderDelivery, :count)
    expect(recipient.reload.notifications.count).to eq(1)
  end

  it 'ignores invoices whose due date is outside the seven-day notification window' do
    create_payable(Date.current + 12.days)

    expect { described_class.perform_now(Date.current) }.not_to change(FinancialReminderDelivery, :count)
  end

  it 'distinguishes upcoming, due-today, and overdue stages' do
    job = described_class.new

    expect(job.send(:reminder_stage, Date.current + 7.days, Date.current)).to eq('days_7')
    expect(job.send(:reminder_stage, Date.current + 3.days, Date.current)).to eq('days_3')
    expect(job.send(:reminder_stage, Date.current, Date.current)).to eq('today')
    expect(job.send(:reminder_stage, Date.yesterday, Date.current)).to eq('overdue')
  end
end
