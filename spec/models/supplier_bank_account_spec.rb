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

  it 'denies disclosure to an administrator outside the supplier organization' do
    account = described_class.create!(
      organization: supplier.organization, supplier:, holder_name: 'Vendor Holdings',
      bank_name: 'Example Bank', account_number: '999988887777'
    )
    actor = create(:user)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))

    expect { account.reveal!(actor:) }.to raise_error(Pundit::NotAuthorizedError)
    expect(FinancialAuditEvent.where(event: 'bank_account.revealed')).not_to exist
  end

  it 'refuses banking details from another organization' do
    other = create(:supplier)

    account = described_class.new(
      organization: supplier.organization, supplier: other,
      bank_name: 'Banco Demo', holder_name: 'Persona', account_number: '123456'
    )

    expect(account).not_to be_valid
  end

  it 'rejects creating bank accounts for inactive suppliers' do
    supplier.update!(status: :inactive)
    account = described_class.new(
      organization: supplier.organization, supplier:, holder_name: 'Proveedor',
      bank_name: 'Banco Demo', account_number: '1234567890', currency_code: 'MXN'
    )

    expect(account).not_to be_valid
    expect(account.errors[:supplier]).to be_present
  end

  it 'allows historical bank accounts to be edited after supplier deactivation' do
    account = described_class.create!(
      organization: supplier.organization, supplier:, holder_name: 'Proveedor',
      bank_name: 'Banco Demo', account_number: '1234567890', currency_code: 'MXN'
    )
    supplier.update!(status: :inactive)

    expect(account.update(holder_name: 'Proveedor histórico')).to be(true)
  end

  it 'rejects an invalid account number and mismatched SAT bank code' do
    account = described_class.new(
      organization: supplier.organization, supplier:, holder_name: 'Supplier',
      bank_name: 'Demo Bank', account_number: 'abc', currency_code: 'MXN'
    )
    expect(account).not_to be_valid
    expect(account.errors[:account_number]).to be_present

    account.account_number = '1234567890'
    account.sat_bank_code = '002'
    account.clabe = '032180000118359719'
    expect(account).not_to be_valid
    expect(account.errors[:sat_bank_code]).to be_present
  end

  it 'supports an account with no saved account number but valid CLABE' do
    account = described_class.new(
      organization: supplier.organization, supplier:, holder_name: 'Supplier',
      bank_name: 'Demo Bank', clabe: '032180000118359719', currency_code: 'MXN'
    )
    expect(account).to be_valid
    expect(account.masked_number).to eq('•••• 9719')
  end

  it 'normalizes account numbers and currency on validation' do
    account = described_class.new(
      organization: supplier.organization, supplier:, holder_name: 'Supplier',
      bank_name: 'Demo Bank', account_number: ' 1234 5678 ', currency_code: 'mxn'
    )
    account.valid?

    expect(account.account_number).to eq('12345678')
    expect(account.currency_code).to eq('MXN')
    expect(account.last_four).to eq('5678')
  end

  it 'shows an optional card expiration without storing the full card number' do
    account = described_class.create!(
      organization: supplier.organization, supplier:, bank_name: 'BBVA México',
      holder_name: 'Vendor', account_number: '1234567890', currency_code: 'MXN',
      card_last_four: '6789', card_expiration_month: 8, card_expiration_year: 2029
    )

    expect(account.reload.card_display_number).to eq('•••• •••• •••• 6789')
    expect(account.card_expiration_label).to eq('08/29')
    expect(account.attributes).not_to have_key('card_number')
  end

  it 'requires a complete and valid card preview when any card detail is supplied' do
    account = described_class.new(
      organization: supplier.organization, supplier:, bank_name: 'Example Bank',
      holder_name: 'Vendor', account_number: '1234567890', currency_code: 'MXN',
      card_last_four: 'abcd', card_expiration_month: 13, card_expiration_year: 1999
    )

    expect(account).not_to be_valid
    expect(account.errors.attribute_names).to include(:card_last_four, :card_expiration_month, :card_expiration_year)

    account.assign_attributes(card_last_four: '1234', card_expiration_month: 10, card_expiration_year: 2029)
    expect(account).to be_valid
  end

  it 'shows that the expiry was not registered for a traditional account' do
    account = described_class.new(last_four: '1234')

    expect(account.card_display_number).to eq('•••• •••• •••• 1234')
    expect(account.card_expiration_label).to be_nil
  end

  it 'returns a generic mask when no sensitive account number is present' do
    account = described_class.new

    expect(account.masked_number).to eq('••••')
  end

  it 'requires a bank name when no SAT bank code is selected' do
    account = described_class.new(
      organization: supplier.organization, supplier:, holder_name: 'Vendor',
      account_number: '1234567890', currency_code: 'MXN'
    )

    expect(account).not_to be_valid
    expect(account.errors[:bank_name]).to be_present
  end

  it 'rejects a supplied bank code when a CLABE belongs to a different bank' do
    account = described_class.new(
      organization: supplier.organization, supplier:, holder_name: 'Vendor',
      bank_name: 'Bank', sat_bank_code: '002', clabe: '032180000118359719',
      currency_code: 'MXN'
    )

    expect(account).not_to be_valid
    expect(account.errors[:sat_bank_code]).to be_present
  end
end
