# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Full Delta POS seeds', type: :model do
  let(:seeded_models) do
    [
      Organization, OrganizationSetting, User, UserRole, OrganizationMembership,
      Employee, PaymentIntegration, InventoryMovement, PurchaseRequest, PurchaseRequestItem,
      PurchaseQuotation, PurchaseQuotationItem, PurchaseOrder, PurchaseOrderItem,
      SupplierInvoice, SupplierInvoiceLine,
      SystemRole, Permission, SystemRolePermission, Language, Translate, SatMonth,
      Supplier, Contact, Address, SupplierSchedule, SupplierEvent, SupplierProduct,
      SupplierProductPrice, SupplierBankAccount, Product, Inventory,
      Branch, Category, Client, Country, Currency, CountryCurrency,
      ActiveStorage::Attachment, ActiveStorage::Blob, SatFiscalRegime, SatBank,
      SatCfdiUse, SatCountry, SatCurrency, SatExportType, SatFactorType,
      SatPaymentMethod, SatPaymentMethodType, SatPeriodicity, SatRelationshipType,
      SatTaxCode, SatTaxObject, SatUnitKey, SatVoucherType
    ]
  end

  def seeded_identifiers
    seeded_models.to_h do |model|
      identifier = model.column_names.include?('id') ? :id : :code
      [model.name, model.order(identifier).pluck(identifier)]
    end
  end

  it 'backfills missing demo relationships and documents without duplicating existing data' do
    Rails.application.load_seed
    supplier = Supplier.find_by!(code: 'SUP-0001')
    other_supplier = Supplier.find_by!(code: 'SUP-0002')
    removed_offer = other_supplier.supplier_products.order(:id).first!
    product = removed_offer.product
    original_history_count = SupplierProductPrice.count
    SupplierProductPrice.where(supplier_product_id: removed_offer.id).delete_all
    removed_offer.destroy!
    filename = 'delta-demo-sup-0001-nota.txt'
    missing_attachment = supplier.documents.attachments.joins(:blob)
                                 .find_by!(active_storage_blobs: { filename: })
    SupplierDocument.with_deleted.where(attachment_id: missing_attachment.id).delete_all
    missing_attachment.purge
    retained_ids = supplier.documents.attachments.pluck(:id).sort

    Rails.application.load_seed

    expect(other_supplier.supplier_products.exists?(product_id: product.id)).to be(true)
    expect(supplier.documents.attachments.pluck(:id)).to include(*retained_ids)
    matches = supplier.documents.attachments.joins(:blob).where(active_storage_blobs: { filename: })
    expect(matches.count).to eq(1)
    expect(SupplierProductPrice.count).to eq(original_history_count)
    expect(other_supplier.supplier_products.group(:product_id, :presentation_name).count.values.max).to eq(1)

    ids = seeded_identifiers
    Rails.application.load_seed
    expect(seeded_identifiers).to eq(ids)
  end

  it 'makes all seeded users visible within the administrator tenant' do
    Rails.application.load_seed

    admin = User.find_by!(email: 'administrador@delta.com')
    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    expect(admin.organization_memberships.active.where(organization:, deleted_at: nil)).to exist

    emails = (1..30).map { |number| "user#{number}@delta.com" }
    users = User.where(email: emails)
    expect(users.count).to eq(30)
    memberships = OrganizationMembership.where(
      organization:, user_id: users.select(:id), status: :active, deleted_at: nil
    )
    expect(memberships.count).to eq(30)
    employees = users.joins(:employee).where(employees: { organization_id: organization.id })
    expect(employees.count).to eq(30)
    expect(admin.employee&.organization).to eq(organization)

    expect(organization.purchase_requests.count).to be >= 24
    expect(organization.purchase_quotations.count).to be >= 20
    expect(organization.purchase_orders.count).to be >= 20
    expect(organization.supplier_invoices.draft.count).to be >= 20
    expect(organization.payment_integrations.pending.count).to eq(2)
    expect(organization.inventories.select(:branch_id).distinct.count).to be >= 3
    expect(InventoryMovement.where(organization:).count).to be_positive
  end

  it 'does not duplicate records or reset manual supplier and login changes on a second run' do
    Rails.application.load_seed
    counts = seeded_models.to_h { |model| [model.name, model.count] }
    identifiers = seeded_identifiers
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
    expect(seeded_identifiers).to eq(identifiers)
    expect(supplier.reload.legal_name).to eq('Datos fiscales revisados')
    expect(admin.reload.valid_password?('PasswordManual#2026')).to be(true)
    expect(product.reload.name).to eq('Producto editado manualmente')
    expect(category.reload.name).to eq('Categoría editada manualmente')
    expect(bank_account.reload.holder_name).to eq('Titular editado manualmente')
    expect(SupplierProduct.count).to be_positive
    expect(SupplierBankAccount.count).to eq(supplier.organization.suppliers.available.count)
    expect(Supplier.where(code: 'SUP-0001').first.documents.attachments.count).to be >= 20
    sample_names = supplier.documents.attachments.joins(:blob).pluck('active_storage_blobs.filename')
    expect(sample_names).to include('delta-demo-sup-0001-fotografia.png')
    expect(SupplierProduct.group(:supplier_id).count.keys.length)
      .to eq(Supplier.where(code: (1..SupplierExamples::COUNT).map { |n| format('SUP-%04d', n) })
                     .available.count)
  end
end
