# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account payable reminder decision branches' do
  let(:job) { AccountsPayableReminderJob.new }

  it 'does not notify for ordinary non-milestone days' do
    expect(job.send(:reminder_stage, Date.tomorrow + 1.day, Date.current)).to be_nil
    expect(job.send(:reminder_stage, Date.tomorrow + 3.days, Date.current)).to be_nil
  end

  it 'notifies one day before the due date' do
    expect(job.send(:reminder_stage, Date.tomorrow, Date.current)).to eq('days_1')
  end

  it 'ignores payables with no outstanding amount' do
    payable = double(balance: 0.to_d)
    expect { job.process_payable(payable, Date.current) }.not_to raise_error
  end

  it 'skips payables outside reminder milestones' do
    payable = double(balance: 10.to_d, due_on: Date.current + 2.days)
    expect { job.process_payable(payable, Date.current) }.not_to raise_error
  end

  it 'does not deliver to users without financial permission' do
    organization = create(:organization)
    supplier = create(:supplier, organization:)
    creator = create(:user)
    recipient = create(:user)
    create(:organization_membership, user: recipient, organization:)
    invoice = SupplierInvoice.create!(
      organization:, supplier:, currency: supplier.currency, created_by: creator,
      issued_on: Date.current, received_on: Date.current, due_on: Date.current,
      subtotal: 20, total: 20
    )
    payable = AccountsPayable::PostInvoice.call(invoice:, actor: creator)
    allow_any_instance_of(User).to receive(:admin?).and_return(false)
    allow_any_instance_of(User).to receive(:permission?).with('accounts_payable.view').and_return(false)

    expect { job.process_payable(payable, Date.current) }
      .not_to change(FinancialReminderDelivery, :count)
  end
end
