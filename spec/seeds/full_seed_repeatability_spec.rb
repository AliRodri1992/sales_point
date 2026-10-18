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
    supplier = Supplier.find_by!(code: 'SUP-0001')
    supplier.update!(legal_name: 'Datos fiscales revisados')
    admin = User.find_by!(email: 'administrador@delta.com')
    admin.update!(password: 'PasswordManual#2026', password_confirmation: 'PasswordManual#2026')

    Rails.application.load_seed

    expect(seeded_models.to_h { |model| [model.name, model.count] }).to eq(counts)
    expect(supplier.reload.legal_name).to eq('Datos fiscales revisados')
    expect(admin.reload.valid_password?('PasswordManual#2026')).to be(true)
    expect(SupplierProduct.count).to be_positive
    expect(SupplierBankAccount.count).to eq(SupplierExamples::COUNT)
    expect(Supplier.where(code: 'SUP-0001').first.documents.attachments.count).to be >= 19
    expect(SupplierProduct.group(:supplier_id).count.keys.length).to eq(SupplierExamples::COUNT)
  end
end
