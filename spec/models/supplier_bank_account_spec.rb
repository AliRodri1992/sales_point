# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierBankAccount do
  let(:supplier) { create(:supplier) }
  let(:valid_clabe) { '032180000118359719' }

  def bank_account(attributes = {})
    described_class.new({
      organization: supplier.organization, supplier:,
      holder_name: 'Proveedor de prueba', bank_name: 'Banco Demo',
      currency_code: 'MXN', clabe: valid_clabe
    }.merge(attributes))
  end

  it 'encrypts and masks the validated Mexican CLABE' do
    account = bank_account
    account.save!

    expect(account.masked_number).to eq('•••• 9719')
    expect(account.reload.clabe).to eq(valid_clabe)
    expect(account.ciphertext_for(:clabe)).not_to include(valid_clabe)
  end

  it 'requires a CLABE for every bank account' do
    account = bank_account(clabe: nil)

    expect(account).not_to be_valid
    expect(account.errors[:clabe]).to be_present
  end

  it 'rejects invalid CLABE length and check digits' do
    expect(bank_account(clabe: '1234')).not_to be_valid
    invalid_check_digit = bank_account(clabe: '032180000118359718')
    expect(invalid_check_digit).not_to be_valid
    expect(invalid_check_digit.errors[:clabe]).to be_present
  end

  it 'derives the active SAT bank from the CLABE when available' do
    bank = create(:sat_bank, code: '032', name: 'Bank of Mexico')
    account = bank_account(sat_bank_code: nil, bank_name: nil)

    expect(account).to be_valid
    expect(account.sat_bank_code).to eq(bank.code)
  end

  it 'refuses mismatched SAT bank codes' do
    create(:sat_bank, code: '002', name: 'Other Bank')
    account = bank_account(sat_bank_code: '002')

    expect(account).not_to be_valid
    expect(account.errors[:sat_bank_code]).to be_present
  end

  it 'does not expose removed account or card attributes' do
    account = bank_account

    expect(account).not_to respond_to(:account_number, :card_number, :card_last_four)
    expect(account.attributes).not_to have_key('account_number')
    expect(account.attributes).not_to have_key('card_number')
    expect(account.attributes).not_to have_key('card_last_four')
  end

  it 'rejects a different supplier organization' do
    account = bank_account(supplier: create(:supplier))

    expect(account).not_to be_valid
    expect(account.errors[:supplier]).to be_present
  end

  it 'rejects creation for an inactive supplier' do
    supplier.update!(status: :inactive)
    account = bank_account

    expect(account).not_to be_valid
    expect(account.errors[:supplier]).to be_present
  end

  it 'allows editing a historical bank account after supplier deactivation' do
    account = bank_account
    account.save!
    supplier.update!(status: :inactive)

    expect(account.update(holder_name: 'Proveedor histórico')).to be(true)
  end

  it 'normalizes CLABE spacing and currency casing' do
    account = bank_account(clabe: '032 180 000 118 359 719', currency_code: 'mxn')

    expect(account).to be_valid
    expect(account.clabe).to eq(valid_clabe)
    expect(account.currency_code).to eq('MXN')
  end

  it 'keeps verification date manual and clears it when verification is reversed' do
    account = bank_account
    account.save!
    expect(account.verified_at).to be_nil

    account.update!(verification_status: 'verified')
    expect(account.verified_at).to be_nil

    verified_at = Time.zone.parse('2026-10-31 12:00:00')
    account.update!(verified_at:)
    expect(account.reload.verified_at).to eq(verified_at)

    account.update!(verification_status: 'rejected')
    expect(account.reload.verified_at).to be_nil
  end

  it 'requires a blocking reason and removes primary status for blocked accounts' do
    account = bank_account
    account.save!

    expect(account.update(status: 'blocked', blocked_reason: '')).to be(false)
    account.update!(status: 'blocked', blocked_reason: 'Cuenta comprometida', primary: true)
    expect(account.reload.primary).to be(false)
    expect(account.blocked_reason).to eq('Cuenta comprometida')

    account.update!(status: 'active')
    expect(account.reload.blocked_reason).to be_nil
  end

  it 'keeps archived bank accounts accessible only through soft-deleted queries' do
    account = bank_account
    account.save!
    account.destroy!

    expect(described_class.with_deleted.find(account.id).deleted_at).to be_present
    expect(described_class.where(id: account.id)).not_to exist
  end

  it 'rejects invalid bank and holder names through model validations' do
    account = bank_account(bank_name: 'X' * 121, holder_name: '')

    expect(account).not_to be_valid
    expect(account.errors[:bank_name]).to be_present
    expect(account.errors[:holder_name]).to be_present
  end

  it 'protects disclosure from users outside the supplier organization' do
    account = bank_account
    account.save!
    actor = create(:user)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))

    expect { account.reveal!(actor:) }.to raise_error(Pundit::NotAuthorizedError)
    expect(FinancialAuditEvent.where(event: 'bank_account.revealed')).not_to exist
  end

  it 'rejects a bank account that is not assigned to a supplier' do
    account = bank_account(supplier: nil)

    expect(account).not_to be_valid
    expect(account.errors[:supplier]).to be_present
  end
end
