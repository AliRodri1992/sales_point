# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierBankAccountPolicy do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }
  let(:account) do
    SupplierBankAccount.create!(
      organization:, supplier:, bank_name: 'Example Bank', holder_name: 'Supplier',
      account_number: '123456789012', currency_code: 'MXN'
    )
  end

  before do
    create(:organization_membership, user:, organization:)
  end

  it 'allows bank account managers to list and edit without unrelated finance access' do
    allow(user).to receive(:permission?) { |code| code == 'accounts_payable.banks.manage' }

    policy = described_class.new(user, account)
    expect(policy.index?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.reveal?).to be(false)
    expect(described_class::Scope.new(user, SupplierBankAccount.all).resolve).to include(account)
  end

  it 'allows bank account viewers to list, but not change or reveal, account details' do
    allow(user).to receive(:permission?) { |code| code == 'accounts_payable.banks.view' }

    policy = described_class.new(user, account)
    expect(policy.index?).to be(true)
    expect(policy.create?).to be(false)
    expect(policy.reveal?).to be(false)
  end

  it 'does not give a reveal-only user access to the supplier catalogue' do
    allow(user).to receive(:permission?) { |code| code == 'accounts_payable.banks.reveal' }

    expect(SupplierPolicy.new(user, Supplier).index?).to be(false)
    expect(SupplierPolicy.new(user, supplier).show?).to be(false)
  end

  it 'does not expose an account from another organization to a permitted manager' do
    other_supplier = create(:supplier, organization: create(:organization))
    other_account = SupplierBankAccount.create!(
      organization: other_supplier.organization, supplier: other_supplier,
      bank_name: 'Different Bank', holder_name: 'Other Supplier',
      account_number: '999988887777', currency_code: 'MXN'
    )
    allow(user).to receive(:permission?) { |code| code == 'accounts_payable.banks.manage' }

    expect(described_class.new(user, other_account).index?).to be(false)
    results = described_class::Scope.new(user, SupplierBankAccount.all).resolve
    expect(results).not_to include(other_account)
  end
end
