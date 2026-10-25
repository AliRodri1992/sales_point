# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier bank accounts list', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def bank_account(attributes = {})
    SupplierBankAccount.create!({
      organization:, supplier:, bank_name: 'Example Bank',
      holder_name: 'Vendor Holdings', account_number: '123456789012',
      currency_code: 'MXN'
    }.merge(attributes))
  end

  def document
    Nokogiri::HTML(response.body)
  end

  it 'shows deleted account details masked and restores the same record' do
    account = bank_account
    delete admin_supplier_bank_account_path(supplier, account)
    get admin_supplier_bank_accounts_path(supplier, archived: '1')

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(account.account_number)
    expect(document.text).to include(account.card_display_number)

    patch restore_admin_supplier_bank_account_path(supplier, account)
    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier, archived: '1'))
    expect(account.reload.deleted_at).to be_nil
    expect(account.primary).to be(false)
  end

  it 'shows the reusable illustration and a registration action when no accounts exist' do
    get admin_supplier_bank_accounts_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('[data-bank-accounts-add-tile]')).to be_present
    expect(document.text).to include('No bank accounts registered yet')
    expect(document.at_css("a[href='#{new_admin_supplier_bank_account_path(supplier)}']")).to be_present
    expect(document.css('[data-supplier-bank-accounts-target="card"]')).to be_empty
  end

  it 'renders three-column bank cards with masked data and permission-protected actions' do
    primary = bank_account(primary: true)
    bank_account(bank_name: 'Another Bank', holder_name: 'Vendor Finance',
                 account_number: '9876543210', currency_code: 'USD')

    get admin_supplier_bank_accounts_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('[data-supplier-bank-accounts-target="list"]')['class']).to include('xl:grid-cols-3')
    cards = document.css('[data-supplier-bank-accounts-target="card"]')
    expect(cards.length).to eq(2)
    expect(document.text).to include('Example Bank', 'Another Bank')
    expect(document.text).not_to include('Vendor Finance')
    expect(document.text).to include(primary.card_display_number)
    expect(document.at_css('[title="Primary"]')).to be_present
    expect(document.text).not_to include('123456789012', '9876543210')
    expect(response.body).not_to include('123456789012', '9876543210')
    expect(document.css('a[href^="/admin/suppliers/"][href*="/bank_accounts/"][href$="/edit"]').size).to eq(2)
    expect(document.css("form[action$='/bank_accounts/#{primary.id}']").size).to eq(1)
    expect(document.at_css('[data-bank-accounts-empty]')).to be_nil
  end

  it 'only renders active accounts from the requested supplier and organization' do
    bank_account
    bank_account(bank_name: 'Archived Bank', deleted_at: Time.current)
    other_supplier = create(:supplier, organization:)
    bank_account(supplier: other_supplier, bank_name: 'Other Supplier Bank')
    external = create(:supplier, organization: create(:organization))
    bank_account(supplier: external, organization: external.organization, bank_name: 'Outside Bank')

    get admin_supplier_bank_accounts_path(supplier, status: 'active')

    expect(response).to have_http_status(:ok)
    expect(document.css('[data-supplier-bank-accounts-target="card"]').length).to eq(1)
    expect(document.css('[data-supplier-bank-accounts-target="card"]').map(&:text).join)
      .not_to include('Archived Bank', 'Other Supplier Bank', 'Outside Bank')
  end

  it 'provides server-side search, bank filtering, and pagination controls' do
    bank_account(currency_code: 'MXN')
    bank_account(bank_name: 'USD Bank', currency_code: 'USD', account_number: '999900001234')

    get admin_supplier_bank_accounts_path(supplier)

    expect(document.at_css('input[name="q"]')).to be_present
    expect(document.at_css('select[name="bank"] option[value="Example Bank"]')).to be_present
    expect(document.at_css('select[name="bank"] option[value="USD Bank"]')).to be_present
    get admin_supplier_bank_accounts_path(supplier, bank: 'USD Bank', q: 'USD')
    expect(document.css('[data-supplier-bank-accounts-target="card"]').length).to eq(1)
    expect(document.css('[data-supplier-bank-accounts-target="card"]').map(&:text).join)
      .not_to include('Example Bank')
    expect(response.body).not_to include('999900001234')
  end

  it 'paginates and filters more than eight supplier bank accounts' do
    10.times do |index|
      bank_account(bank_name: "Bank #{index}", account_number: format('%012d', index + 1))
    end
    get admin_supplier_bank_accounts_path(supplier)
    expect(document.css('[data-supplier-bank-accounts-target="card"]').size).to eq(8)
    get admin_supplier_bank_accounts_path(supplier, page: 2)
    expect(document.css('[data-supplier-bank-accounts-target="card"]').size).to eq(2)
    get admin_supplier_bank_accounts_path(supplier, q: 'Bank 9')
    expect(document.css('[data-supplier-bank-accounts-target="card"]').size).to eq(1)
  end

  it 'retains the existing card design while masking the encrypted optional card number' do
    account = bank_account(bank_name: 'BBVA México', card_number: '4111111111111111')

    get admin_supplier_bank_accounts_path(supplier)

    card = document.at_css('[data-supplier-bank-accounts-target="card"]')
    expect(card.text).to include('BBVA', '•••• •••• •••• 1111')
    expect(card.text).not_to include('MXN', 'Vendor Holdings', 'BBVA México')
    expect(response.body).not_to include(account.account_number, account.card_number)
    expect(document.at_css('[data-bank-accounts-add-tile]')).to be_present
  end

  it 'registers the CLABE bank lookup controller and never preloads sensitive values' do
    account = bank_account
    get edit_admin_supplier_bank_account_path(supplier, account)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('form[data-controller~="supplier-bank-clabe"]')).to be_present
    expect(document.at_css('input[data-supplier-bank-clabe-target="clabe"]')).to be_present
    expect(document.at_css('select[data-supplier-bank-clabe-target="bank"]')).to be_present
    expect(response.body).not_to include(account.account_number)
  end

  it 'provides account type, blocked reason and verification state without collecting expiry or CVV' do
    get new_admin_supplier_bank_account_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(document.at_css('select[name="supplier_bank_account[account_type]"]')).to be_present
    expect(document.at_css('select[name="supplier_bank_account[verification_status]"]')).to be_present
    expect(document.at_css('textarea[name="supplier_bank_account[blocked_reason]"]')).to be_nil
    expect(document.at_css('select[name="supplier_bank_account[status]"]')).to be_nil
    expect(document.at_css('input[name="supplier_bank_account[card_number]"]')).to be_present
    expect(document.at_css('input[name*="card_expiration"]')).to be_nil
    expect(document.at_css('input[name*="cvv"]')).to be_nil
  end

  it 'keeps only the shared application breadcrumb on both bank account forms' do
    account = bank_account
    [new_admin_supplier_bank_account_path(supplier),
     edit_admin_supplier_bank_account_path(supplier, account)].each do |path|
      get path

      expect(response).to have_http_status(:ok)
      expect(document.css('nav[aria-label] ol li [aria-current="page"]').size).to eq(1)
      expect(document.css('[data-bank-account-form-page] nav')).to be_empty
      expect(document.at_css('nav[aria-label] ol li [aria-current="page"]')).to be_present
    end
  end

  it 'renders the responsive, localized create form with the Deltin sidebar and full-width actions' do
    get new_admin_supplier_bank_account_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('[data-bank-account-form-page="new"]')).to be_present
    expect(document.at_css('form[data-controller~="supplier-bank-form"]')).to be_present
    expect(document.at_css('img[src*="deltin/waving"]')).to be_present
    expect(document.at_css('[data-bank-form-actions] button[type="submit"]')).to be_present
    expect(document.css('[data-bank-form-section]').size).to eq(2)
    expect(document.at_css('select[name="supplier_bank_account[status]"]')).to be_nil
    expect(document.at_css('textarea[name="supplier_bank_account[blocked_reason]"]')).to be_nil
    expect(document.at_css('select[name="supplier_bank_account[verification_status]"]')).to be_present
    expect(document.at_css('[data-supplier-bank-form-target="previewNumber"]')).to be_present
    expect(document.at_css('input[data-supplier-bank-form-target="primary"]')).to be_present
  end

  it 'renders the edit controls and keeps every encrypted input blank' do
    account = bank_account(clabe: '012180001234567899', card_number: '4111111111111111')

    get edit_admin_supplier_bank_account_path(supplier, account)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('[data-bank-account-form-page="edit"]')).to be_present
    expect(document.at_css('select[name="supplier_bank_account[status]"]')).to be_present
    expect(document.at_css('textarea[name="supplier_bank_account[blocked_reason]"]')).to be_present
    %w[clabe account_number card_number].each do |field|
      input = document.at_css("input[name='supplier_bank_account[#{field}]']")
      expect(input['value']).to be_blank
    end
    expect(response.body).not_to include(account.account_number, account.clabe, account.card_number)
  end

  it 'forces new accounts active even when a forged request submits another status' do
    post admin_supplier_bank_accounts_path(supplier), params: {
      supplier_bank_account: {
        bank_name: 'Sample Bank', holder_name: 'Vendor Holdings',
        account_number: '123456789012', currency_code: 'MXN',
        status: 'blocked', blocked_reason: 'Forged'
      }
    }

    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    account = supplier.supplier_bank_accounts.order(:id).last
    expect(account.status).to eq('active')
    expect(account.blocked_reason).to be_nil
  end

  it 'uses model validation with inline messages for each field instead of browser required attributes' do
    get new_admin_supplier_bank_account_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(document.at_css('form[novalidate]')).to be_present
    expect(document.css('[data-bank-account-form-page] form [required]')).to be_empty

    post admin_supplier_bank_accounts_path(supplier), params: {
      supplier_bank_account: {
        holder_name: '', clabe: 'invalid', sat_bank_code: '999',
        bank_name: '', account_number: '12', card_number: '123',
        account_type: 'unknown', currency_code: 'US',
        verification_status: 'invalid'
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    %w[holder_name clabe sat_bank_code account_number card_number
       account_type currency_code verification_status].each do |attribute|
      error = document.at_css(%([data-bank-field-errors="#{attribute}"]))
      input = document.at_css(%([name="supplier_bank_account[#{attribute}]"]))
      expect(error).to be_present
      expect(error.text).to include(SupplierBankAccount.human_attribute_name(attribute))
      expect(input['aria-invalid']).to eq('true')
      expect(input['aria-describedby']).to eq("supplier-bank-#{attribute}-errors")
    end
    expect(document.at_css('[data-bank-field-errors="bank_name"]')).to be_nil
    expect(document.css('[data-bank-account-form-page] form [required]')).to be_empty
  end

  it 'displays a blocked reason error beside its textarea during an invalid edit' do
    account = bank_account
    patch admin_supplier_bank_account_path(supplier, account), params: {
      supplier_bank_account: { status: 'blocked', blocked_reason: '' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    field = document.at_css('[data-supplier-bank-form-target="blockedReasonGroup"]')
    expect(field['class']).not_to include('hidden')
    expect(field.at_css('[data-bank-field-errors="blocked_reason"]')).to be_present
    expect(field.at_css('textarea')['aria-invalid']).to eq('true')
    expect(account.reload.status).to eq('active')
  end

  it 'accepts a verified, blocked account with an explicit reason and server-created verified timestamp' do
    account = bank_account
    patch admin_supplier_bank_account_path(supplier, account), params: {
      supplier_bank_account: { status: 'blocked', blocked_reason: 'Account compromised',
                               verification_status: 'verified', account_type: 'checking' }
    }
    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(account.reload.status).to eq('blocked')
    expect(account.blocked_reason).to eq('Account compromised')
    expect(account.verification_status).to eq('verified')
    expect(account.account_type).to eq('checking')
    expect(account.verified_at).to be_present
  end

  it 'shows bank dossier filters as full-width options without radio buttons' do
    bank_account
    get admin_supplier_path(supplier, tab: 'bank_accounts')
    panel = document.at_css('#supplier-dossier-bank-accounts')
    expect(panel.css('input[type="radio"]')).to be_empty
    expect(panel.css('button[data-option-value]')).not_to be_empty
    expect(panel.css('button[data-option-value]').all? { |button| button['class'].include?('w-full') }).to be(true)
    expect(panel.css('button[role="option"][aria-selected="true"]').size).to eq(2)
    expect(panel.css('[role="listbox"]').size).to eq(2)
    expect(panel.css('input[type="hidden"][name="banks_status"]')).not_to be_empty
  end

  it 'rejects blocking a bank account without a reason' do
    account = bank_account
    patch admin_supplier_bank_account_path(supplier, account), params: {
      supplier_bank_account: { status: 'blocked', blocked_reason: '' }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(account.reload.status).to eq('active')
  end

  it 'filters active and archived cards and shows a restore action for the archived account' do
    bank_account(bank_name: 'Active Bank')
    archived = bank_account(bank_name: 'Old Bank', deleted_at: Time.current)

    get admin_supplier_bank_accounts_path(supplier, status: 'all')
    expect(document.css('[data-supplier-bank-accounts-target="card"]').length).to eq(2)
    expect(document.text).to include('Active', 'Inactive')

    get admin_supplier_bank_accounts_path(supplier, status: 'archived')
    expect(document.css('[data-supplier-bank-accounts-target="card"]').length).to eq(1)
    expect(document.at_css("form[action$='/bank_accounts/#{archived.id}/restore']")).to be_present
    expect(document.at_css('[data-bank-accounts-add-tile]')).to be_nil
  end

  it 'returns to the bank accounts tab of the supplier dossier' do
    bank_account

    get admin_supplier_bank_accounts_path(supplier)

    back_path = admin_supplier_path(supplier, tab: 'bank_accounts')
    back_link = document.at_css("a[href='#{back_path}']")
    expect(back_link).to be_present
    expect(back_link.text).to include('Back to supplier')

    get back_link['href']

    expect(response).to have_http_status(:ok)
    dossier = document.at_css('[data-controller="supplier-dossier"]')
    expect(dossier['data-supplier-dossier-initial-tab-value']).to eq('bank_accounts')
    expect(document.at_css('section[data-section="bank_accounts"]')).to be_present
    expect(document.at_css('button[data-supplier-dossier-target="tab"][data-section="bank_accounts"]'))
      .to be_present
  end

  it 'uses the same return tab when no bank accounts are registered' do
    get admin_supplier_bank_accounts_path(supplier)

    expect(document.at_css("a[href='#{admin_supplier_path(supplier, tab: 'bank_accounts')}']"))
      .to be_present
  end

  it 'accepts a blank SAT bank when editing a bank account with a manual bank name' do
    account = bank_account(bank_name: 'Manual Bank')

    patch admin_supplier_bank_account_path(supplier, account), params: {
      supplier_bank_account: { sat_bank_code: '', bank_name: 'Updated Bank',
                               holder_name: 'Vendor Holdings', currency_code: 'MXN' }
    }

    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(account.reload.sat_bank_code).to be_nil
    expect(account.bank_name).to eq('Updated Bank')
  end

  it 'accepts a blank SAT bank when registering a manual bank account' do
    post admin_supplier_bank_accounts_path(supplier), params: {
      supplier_bank_account: { sat_bank_code: '', bank_name: 'Manual Bank',
                               holder_name: 'Vendor Holdings', account_number: '123456789012',
                               currency_code: 'MXN' }
    }

    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(supplier.supplier_bank_accounts.last.sat_bank_code).to be_nil
  end

  it 'atomically switches the primary bank account for a supplier' do
    original = bank_account(primary: true)
    other = bank_account(bank_name: 'Backup bank', account_number: '999900001234')

    patch admin_supplier_bank_account_path(supplier, other), params: {
      supplier_bank_account: { primary: '1' }
    }

    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(original.reload).not_to be_primary
    expect(other.reload).to be_primary
    expect(supplier.supplier_bank_accounts.active.where(primary: true).count).to eq(1)
  end

  it 'does not demote a valid primary account when a blocked account attempts to become primary' do
    original = bank_account(primary: true)
    other = bank_account(bank_name: 'Backup bank', account_number: '999900001234')

    patch admin_supplier_bank_account_path(supplier, other), params: {
      supplier_bank_account: { primary: '1', status: 'blocked', blocked_reason: 'Cuenta comprometida' }
    }

    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))
    expect(original.reload).to be_primary
    expect(other.reload).not_to be_primary
    expect(other.status).to eq('blocked')
  end

  it 'rolls back the previous primary bank demotion when the replacement is invalid' do
    original = bank_account(primary: true)
    post admin_supplier_bank_accounts_path(supplier), params: {
      supplier_bank_account: { bank_name: 'Backup', account_number: '123456789',
                               holder_name: '', currency_code: 'MXN', primary: '1' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(original.reload).to be_primary
    expect(supplier.supplier_bank_accounts.active.where(primary: true).count).to eq(1)
  end

  it 'uses the existing supplier breadcrumb without adding supplier information cards' do
    get admin_supplier_bank_accounts_path(supplier)

    crumbs = document.css('nav[aria-label] ol li')
    expect(crumbs.map { |item| item.at_css('a, [aria-current="page"]').text.strip }).to eq(
      ['Home', 'Suppliers', supplier.name, 'Bank accounts']
    )
    expect(crumbs[2].at_css('a')['href']).to eq(admin_supplier_path(supplier))
    expect(crumbs.last.at_css('[aria-current="page"]')).to be_present
    expect(document.at_css('[data-bank-accounts-supplier-summary]')).to be_nil
  end

  it 'blocks new banking details when the supplier is inactive but preserves history' do
    existing = bank_account
    supplier.update!(status: :inactive)

    get new_admin_supplier_bank_account_path(supplier)
    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))

    expect do
      post admin_supplier_bank_accounts_path(supplier), params: {
        supplier_bank_account: { bank_name: 'Not allowed', holder_name: 'New',
                                 account_number: '55554444', currency_code: 'MXN' }
      }
    end.not_to change(SupplierBankAccount, :count)
    expect(response).to redirect_to(admin_supplier_bank_accounts_path(supplier))

    get admin_supplier_bank_accounts_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(document.text).to include(existing.card_display_number)
  end

  it 'does not expose banking records belonging to another organization in edit or reveal' do
    external = create(:supplier, organization: create(:organization))
    account = bank_account(supplier: external, organization: external.organization)

    get edit_admin_supplier_bank_account_path(supplier, account)
    expect(response).to have_http_status(:not_found)

    sign_in user
    post reveal_admin_supplier_bank_account_path(supplier, account)
    expect(response).to have_http_status(:not_found)
  end
end
