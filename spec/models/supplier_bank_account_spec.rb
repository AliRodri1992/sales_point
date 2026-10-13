# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierBankAccount do
  let(:supplier) { create(:supplier) }

  it 'encrypts and masks a validated Mexican CLABE' do
    account = described_class.create!(
      organization: supplier.organization, supplier:, holder_name: 'Proveedor',
      sat_bank_code: nil, bank_name: 'Banco Demo',
      clabe: '032180000118359719', currency_code: 'MXN'
    )

    expect(account.masked_number).to eq('•••• 9719')
    expect(account.reload.clabe).to eq('032180000118359719')
    expect(account.ciphertext_for(:clabe)).not_to include('032180000118359719')
  end

  it 'rejects an invalid CLABE control digit' do
    account = described_class.new(
      organization: supplier.organization, supplier:, holder_name: 'Proveedor',
      bank_name: 'Banco Demo', clabe: '032180000118359718'
    )

    expect(account).not_to be_valid
    expect(account.errors[:clabe]).to be_present
  end

  it 'refuses banking details from another organization' do
    other = create(:supplier)

    account = described_class.new(
      organization: supplier.organization, supplier: other,
      bank_name: 'Banco Demo', holder_name: 'Persona', account_number: '123456'
    )

    expect(account).not_to be_valid
  end
end
