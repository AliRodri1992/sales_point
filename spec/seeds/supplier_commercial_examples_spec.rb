# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_examples')
require Rails.root.join('db/seeds/supplier_commercial_examples')

RSpec.describe SupplierCommercialExamples do
  let!(:administrator) { create(:user, email: 'administrador@delta.com') }
  let!(:currency) { create(:currency, code: 'MXN') }

  before do
    SupplierExamples.seed!
    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    8.times { |index| create(:product, organization:, code: format('PROD%04d', index + 1)) }
  end

  it 'creates repeatable supplier offers, active product preferences and price history' do
    described_class.seed_products!
    original_ids = SupplierProduct.order(:id).pluck(:id)
    original_history = SupplierProductPrice.count
    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)

    expect(original_ids).not_to be_empty
    expect(organization.products.where.not(preferred_supplier_id: nil).count).to be_positive
    expect(SupplierProduct.group(:organization_id, :supplier_id, :product_id, :presentation_name)
                          .count.values.uniq).to eq([1])
    expect(SupplierProductPrice.count).to eq(SupplierProduct.count)

    described_class.seed_products!

    expect(SupplierProduct.order(:id).pluck(:id)).to eq(original_ids)
    expect(SupplierProductPrice.count).to eq(original_history)
    expect(SupplierProductPrice.count).to eq(SupplierProduct.count)
  end

  it 'preserves edited offer values and manually removed preferred suppliers on a second run' do
    described_class.seed_products!
    offer = SupplierProduct.order(:id).first
    product = offer.product
    price_history_before = SupplierProductPrice.count
    offer.update!(purchase_price: 987)
    product.update!(preferred_supplier: nil)

    described_class.seed_products!

    expect(offer.reload.purchase_price).to eq(987)
    expect(product.reload.preferred_supplier).to be_nil
    expect(SupplierProductPrice.count).to eq(price_history_before + 1)
  end

  it 'links inactive suppliers and inactive demo products without activating unavailable offers' do
    org = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    inactive_product = create(:product, organization: org, code: 'PROD0015', status: :inactive)
    described_class.seed_products!

    inactive_supplier = org.suppliers.find_by!(code: 'SUP-0005')
    expect(inactive_supplier).to be_inactive
    expect(inactive_supplier.supplier_products.count).to eq(described_class::OFFERS_PER_SUPPLIER)
    expect(inactive_supplier.supplier_products.where(active: true)).to be_empty
    expect(inactive_product.supplier_products.count).to be_positive
    expect(inactive_product.supplier_products.where(active: true)).to be_empty

    count = SupplierProduct.count
    described_class.seed_products!
    expect(SupplierProduct.count).to eq(count)
  end

  it 'does not attach demonstration offers to manually created catalog products' do
    org = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    manually_added = create(:product, organization: org, code: 'OWNED-ITEM')

    described_class.seed_products!

    expect(manually_added.supplier_products).to be_empty
  end

  it 'preserves manual supplier bank accounts without generating new demo accounts' do
    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    manual = create(:supplier, organization:, code: 'MANUAL-BANK')
    account = manual.supplier_bank_accounts.create!(
      organization:, holder_name: 'Cuenta administrada manualmente',
      bank_name: 'Banco configurado por usuario', currency_code: 'MXN',
      account_number: '9876543210'
    )

    2.times { described_class.seed_bank_accounts! }

    expect(manual.supplier_bank_accounts.pluck(:id)).to eq([account.id])
    expect(account.reload.holder_name).to eq('Cuenta administrada manualmente')
    expect(organization.supplier_bank_accounts.count).to eq(SupplierExamples::COUNT + 1)
  end

  it 'creates encrypted, checksum-valid and nonduplicated demo bank accounts' do
    2.times { described_class.seed_bank_accounts! }

    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    expect(SupplierBankAccount.where(organization:).count).to eq(SupplierExamples::COUNT)

    account = organization.supplier_bank_accounts.order(:id).first
    expect(account).to be_valid
    expect(account.primary?).to be(true)
    expect(account.clabe.length).to eq(18)
    expect(account.clabe).to start_with('999')
    expect(account.bank_name).to include('NO REAL')
    expect(account.ciphertext_for(:clabe)).not_to include(account.clabe)
  end

  it 'does not replace bank details or recreate an archived bank account' do
    described_class.seed_bank_accounts!
    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    account = organization.supplier_bank_accounts.order(:id).first
    account.update!(holder_name: 'TITULAR EDITADO')
    account.update!(deleted_at: Time.current)

    described_class.seed_bank_accounts!

    expect(account.reload.holder_name).to eq('TITULAR EDITADO')
    expect(account.deleted_at).to be_present
    expect(account.supplier.supplier_bank_accounts.count).to eq(1)
    expect(organization.supplier_bank_accounts.count).to eq(SupplierExamples::COUNT)
  end

  it 'does not create synthetic records in production' do
    allow(Rails.env).to receive(:production?).and_return(true)
    described_class.seed_products!
    described_class.seed_bank_accounts!

    expect(SupplierProduct.count).to eq(0)
    expect(SupplierBankAccount.count).to eq(0)
  end
end
