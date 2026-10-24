# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier archived financial records', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'restores an archived product offer from the supplier dossier' do
    product = create(:product, organization:)
    offer = SupplierProduct.create!(
      organization:, supplier:, product:, currency: supplier.currency,
      presentation_name: 'Box', units_per_package: 12, purchase_price: 240
    )
    offer.update!(deleted_at: Time.current, active: false)

    visit admin_supplier_supplier_products_path(supplier, archived: '1')
    expect(page).to have_css('[data-product-offer-row]', text: product.name)

    within('[data-product-offer-row]', text: product.name) do
      find('summary').click
      click_button I18n.t('admin.supplier_archive.restore', locale: :en)
    end

    expect(page).to have_no_css('[data-product-offer-row]', text: product.name)
    expect(offer.reload.deleted_at).to be_nil
    expect(offer).to be_active
  end

  scenario 'restores an archived bank account while masking its number' do
    account = SupplierBankAccount.create!(
      organization:, supplier:, holder_name: 'Acme Supply',
      bank_name: 'Demo Bank', account_number: '1234567890', currency_code: 'MXN'
    )
    account.update!(deleted_at: Time.current)

    visit admin_supplier_bank_accounts_path(supplier, archived: '1')
    expect(page).to have_content('Acme Supply')
    expect(page).to have_content('7890')
    expect(page).to have_no_content('1234567890')

    click_button I18n.t('admin.supplier_archive.restore', locale: :en)

    expect(page).to have_no_content('Acme Supply')
    expect(account.reload.deleted_at).to be_nil
    expect(page).to have_current_path(admin_supplier_bank_accounts_path(supplier, archived: '1'))
  end
end
