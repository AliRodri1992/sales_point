# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Financial security validation' do
  let(:supplier) { create(:supplier) }
  let(:organization) { supplier.organization }
  let(:currency) { supplier.currency }
  let(:user) { create(:user) }

  it 'rejects invalid supplier account numbers' do
    account = SupplierBankAccount.new(
      organization:, supplier:, bank_name: 'Demo', holder_name: 'Owner',
      account_number: 'abc123', currency_code: currency.code
    )
    expect(account).not_to be_valid
    expect(account.errors[:account_number]).to be_present
  end

  it 'rejects a CLABE that belongs to another bank code' do
    account = SupplierBankAccount.new(
      organization:, supplier:, bank_name: 'Demo', holder_name: 'Owner',
      clabe: '032180000118359719', sat_bank_code: '001', currency_code: currency.code
    )
    expect(account).not_to be_valid
    expect(account.errors[:sat_bank_code]).to be_present
  end

  it 'redacts nested account and CLABE information in immutable financial audit' do
    payment = SupplierPayment.create!(
      organization:, supplier:, currency:, created_by: user, paid_on: Date.current, amount: 10
    )
    audit = FinancialAuditEvent.record!(
      organization:, actor: user, event: 'payment.test', subject: payment,
      details: { account_number: 'secret', nested: { 'clabe' => 'another-secret' },
                 entries: [{ bank_account: 'third-secret', reference: 'safe' }] }
    )

    expect(audit.details.to_s).not_to include('another-secret', 'third-secret', 'secret')
    expect(audit.details.to_s).to include('safe')
    expect { audit.destroy }.not_to change(FinancialAuditEvent, :count)
  end

  it 'requires the payment bank to belong to the supplier' do
    foreign = create(:supplier, organization:)
    account = SupplierBankAccount.create!(
      organization:, supplier: foreign, bank_name: 'Demo',
      holder_name: 'Owner', account_number: '12345678', currency_code: currency.code
    )
    payment = SupplierPayment.new(
      organization:, supplier:, currency:, created_by: user,
      supplier_bank_account: account, paid_on: Date.current, amount: 10
    )

    expect(payment).not_to be_valid
    expect(payment.errors[:supplier_bank_account]).to be_present
  end
end
