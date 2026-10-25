# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::DossierBankAccountsPage do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }

  def create_account(name:, digits:, deleted_at: nil)
    SupplierBankAccount.create!(
      organization:, supplier:, bank_name: name, holder_name: 'Supplier',
      account_number: "12345678#{digits}", currency_code: 'MXN', deleted_at:
    )
  end

  it 'defaults to active accounts with masked-searchable metadata and accurate status counts' do
    create_account(name: 'BBVA México', digits: '1100')
    create_account(name: 'Archive Bank', digits: '2200', deleted_at: Time.current)

    page = described_class.new(supplier:).call

    expect(page.accounts.map(&:bank_name)).to eq(['BBVA México'])
    expect(page.counts).to eq(all: 2, active: 1, archived: 1)
    expect(page.banks).to eq(['BBVA México'])
    expect(page.status).to eq('active')
    expect(page.from).to eq(1)
    expect(page.to).to eq(1)
  end

  it 'filters by bank and searches the final four digits within the supplier' do
    create_account(name: 'BBVA México', digits: '1100')
    create_account(name: 'Santander', digits: '2200')
    other = create(:supplier, organization:)
    SupplierBankAccount.create!(
      organization:, supplier: other, bank_name: 'BBVA México', holder_name: 'Other',
      account_number: '555599991100', currency_code: 'MXN'
    )

    page = described_class.new(supplier:, bank: 'BBVA México', query: '1100').call

    expect(page.accounts.map(&:bank_name)).to eq(['BBVA México'])
    expect(page.total_count).to eq(1)
  end

  it 'paginates at eight cards without spilling into another supplier' do
    10.times { |n| create_account(name: 'Example Bank', digits: format('%04d', n)) }

    page = described_class.new(supplier:, page: 2).call

    expect(page.page).to eq(2)
    expect(page.total_pages).to eq(2)
    expect(page.accounts.length).to eq(2)
    expect(page.from).to eq(9)
    expect(page.to).to eq(10)
  end

  it 'includes archived accounts only when explicitly selected' do
    create_account(name: 'Archived', digits: '1234', deleted_at: Time.current)

    archived = described_class.new(supplier:, status: 'archived').call
    invalid = described_class.new(supplier:, status: 'unknown').call

    expect(archived.accounts.map(&:bank_name)).to eq(['Archived'])
    expect(archived.banks).to eq(['Archived'])
    expect(invalid.status).to eq('active')
    expect(invalid.accounts).to be_empty
    expect(invalid.from).to eq(0)
    expect(invalid.to).to eq(0)
  end

  it 'includes active and archived records in the all view and prefers SAT bank names' do
    bank = create(:sat_bank, code: '032', name: 'Banco SAT')
    SupplierBankAccount.create!(
      organization:, supplier:, sat_bank_code: bank.code, holder_name: 'Supplier',
      account_number: '1234567890', currency_code: 'MXN'
    )
    create_account(name: 'Archived Bank', digits: '1234', deleted_at: Time.current)

    page = described_class.new(supplier:, status: 'all', bank: 'Banco SAT').call
    expect(page.banks).to include('Banco SAT', 'Archived Bank')
    expect(page.accounts.count).to eq(1)
    expect(page.accounts.first.sat_bank.name).to eq('Banco SAT')

    unfiltered = described_class.new(supplier:, status: 'all').call
    expect(unfiltered.accounts.count).to eq(2)
    expect(unfiltered.counts).to eq(all: 2, active: 1, archived: 1)
  end
end
