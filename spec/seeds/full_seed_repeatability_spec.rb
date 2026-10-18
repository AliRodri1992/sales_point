# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Full Delta POS seeds', type: :model do
  let(:seeded_models) do
    [
      Organization, OrganizationSetting, User, UserRole, OrganizationMembership,
      SystemRole, Permission, SystemRolePermission, Language, Translate, SatMonth,
      Supplier, Contact, Address, SupplierSchedule, SupplierProduct,
      SupplierProductPrice, SupplierBankAccount, Product, Inventory,
      Branch, Category, Client, Country, Currency, CountryCurrency,
      ActiveStorage::Attachment, ActiveStorage::Blob, SatFiscalRegime
    ]
  end

  it 'does not duplicate records or reset manual supplier and login changes on a second run' do
    Rails.application.load_seed
    counts = seeded_models.to_h { |model| [model.name, model.count] }
    identifiers = seeded_models.to_h { |model| [model.name, model.order(model.primary_key).pluck(model.primary_key)] }
    supplier = Supplier.find_by!(code: 'SUP-0001')
    supplier.update!(legal_name: 'Datos fiscales revisados')
    admin = User.find_by!(email: 'administrador@delta.com')
    admin.update!(password: 'PasswordManual#2026', password_confirmation: 'PasswordManual#2026')
    product = supplier.organization.products.find_by!(code: 'PROD0001')
    product.update!(name: 'Producto editado manualmente')
    category = Category.find_by!(code: 'cat0001')
    category.update!(name: 'Categoría editada manualmente')
    bank_account = supplier.supplier_bank_accounts.first!
    bank_account.update!(holder_name: 'Titular editado manualmente')

    Rails.application.load_seed

    expect(seeded_models.to_h { |model| [model.name, model.count] }).to eq(counts)
    expect(seeded_models.to_h { |model| [model.name, model.order(:id).pluck(:id)] }).to eq(identifiers)
    expect(supplier.reload.legal_name).to eq('Datos fiscales revisados')
    expect(admin.reload.valid_password?('PasswordManual#2026')).to be(true)
    expect(product.reload.name).to eq('Producto editado manualmente')
    expect(category.reload.name).to eq('Categoría editada manualmente')
    expect(bank_account.reload.holder_name).to eq('Titular editado manualmente')
    expect(SupplierProduct.count).to be_positive
    expect(SupplierBankAccount.count).to eq(SupplierExamples::COUNT)
    expect(Supplier.where(code: 'SUP-0001').first.documents.attachments.count).to be >= 20
    sample_names = supplier.documents.attachments.joins(:blob).pluck('active_storage_blobs.filename')
    expect(sample_names).to include('delta-demo-sup-0001-fotografia.png')
    expect(SupplierProduct.group(:supplier_id).count.keys.length).to eq(SupplierExamples::COUNT)
  end
end
