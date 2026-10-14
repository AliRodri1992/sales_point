# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Financial credit and banking form paths', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user, :english) }
  let(:currency) { supplier.currency }

  before do
    create(:organization_membership, user: actor, organization:)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in actor
  end

  def credit_params(overrides = {})
    {
      supplier_id: supplier.id, currency_id: currency.id,
      issued_on: Date.current, total: 50, folio: 'CN-01'
    }.merge(overrides)
  end

  def upload
    Rack::Test::UploadedFile.new(
      StringIO.new('<Comprobante/>'), 'application/xml', original_filename: 'credit.xml'
    )
  end

  def parsed_credit(overrides = {})
    {
      uuid: SecureRandom.uuid, total: 25,
      issued_on: Date.current, issuer_rfc: supplier.rfc,
      receiver_rfc: organization.tax_id, currency_code: currency.code
    }.merge(overrides)
  end

  it 'displays a new supplier credit-note form' do
    get new_admin_supplier_credit_note_path
    expect(response).to have_http_status(:ok)
  end

  it 'accepts manual credit note details' do
    post admin_supplier_credit_notes_path, params: { supplier_credit_note: credit_params }
    expect(response).to redirect_to(admin_supplier_credit_note_path(SupplierCreditNote.last))
    expect(SupplierCreditNote.last).to have_attributes(total: 50, supplier:)
  end

  it 'rejects invalid manual credit note amounts' do
    post admin_supplier_credit_notes_path, params: {
      supplier_credit_note: credit_params(total: -1)
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'parses and attaches fiscal credit XML before saving' do
    allow(AccountsPayable::CfdiParser).to receive(:call).and_return(parsed_credit)
    post admin_supplier_credit_notes_path, params: {
      supplier_credit_note: credit_params(xml_document: upload)
    }
    expect(response).to redirect_to(admin_supplier_credit_note_path(SupplierCreditNote.last))
    expect(SupplierCreditNote.last.xml_document).to be_attached
    expect(SupplierCreditNote.last.total).to eq(25)
    expect(AccountsPayable::CfdiParser).to have_received(:call).with(hash_including(expected_type: 'E'))
  end

  {
    'unrecognized supplier' => { supplier_id: 0 },
    'issuer RFC mismatch' => { issuer_rfc: 'INVALIDRFC000' },
    'receiver RFC mismatch' => { receiver_rfc: 'INVALIDRFC000' },
    'currency mismatch' => { currency_code: 'ZZZ' }
  }.each do |case_name, mismatch|
    it "rejects credit XML with #{case_name}" do
      modified_params = credit_params
      modified_params[:supplier_id] = mismatch.fetch(:supplier_id) if mismatch.key?(:supplier_id)
      data = parsed_credit(mismatch.except(:supplier_id))
      allow(AccountsPayable::CfdiParser).to receive(:call).and_return(data)

      post admin_supplier_credit_notes_path, params: {
        supplier_credit_note: modified_params.merge(xml_document: upload)
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(SupplierCreditNote.count).to eq(0)
    end
  end

  it 'rejects malformed credit XML' do
    allow(AccountsPayable::CfdiParser).to receive(:call).and_raise(ArgumentError, 'Malformed CFDI')
    post admin_supplier_credit_notes_path, params: {
      supplier_credit_note: credit_params(xml_document: upload)
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(SupplierCreditNote.count).to eq(0)
  end

  def bank_params(overrides = {})
    {
      bank_name: 'Local Bank', holder_name: 'Supplier One',
      account_number: '1234567890', currency_code: currency.code
    }.merge(overrides)
  end

  it 'renders the bank account listing and form' do
    get admin_supplier_bank_accounts_path(supplier)
    expect(response).to have_http_status(:ok)
    get new_admin_supplier_bank_account_path(supplier)
    expect(response).to have_http_status(:ok)
  end

  it 'creates and edits supplier bank accounts' do
    post admin_supplier_bank_accounts_path(supplier), params: {
      supplier_bank_account: bank_params
    }
    record = SupplierBankAccount.last
    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(record.masked_number).to be_present

    get edit_admin_supplier_bank_account_path(supplier, record)
    expect(response).to have_http_status(:ok)
    patch admin_supplier_bank_account_path(supplier, record), params: {
      supplier_bank_account: { bank_name: 'Changed Bank', account_number: '' }
    }
    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(record.reload).to have_attributes(bank_name: 'Changed Bank', account_number: '1234567890')
  end

  it 'rejects invalid bank accounts on create' do
    post admin_supplier_bank_accounts_path(supplier), params: {
      supplier_bank_account: bank_params(account_number: 'INVALID')
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects invalid bank accounts on update' do
    record = SupplierBankAccount.create!(bank_params.merge(organization:, supplier:))
    patch admin_supplier_bank_account_path(supplier, record), params: {
      supplier_bank_account: { account_number: 'not-numeric' }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(record.reload.account_number).to eq('1234567890')
  end
end
