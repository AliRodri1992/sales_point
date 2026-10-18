# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_examples')

RSpec.describe SupplierExamples do
  let!(:administrator) { create(:user, email: 'administrador@delta.com') }
  let!(:currency) { create(:currency, code: 'MXN') }

  it 'creates twenty organization-owned suppliers and their primary contacts' do
    described_class.seed!

    organization = Organization.find_by!(tax_id: described_class::ORGANIZATION_TAX_ID)
    expect(organization.suppliers.count).to eq(20)
    expect(organization.suppliers.where(status: :inactive).count).to eq(4)
    expect(organization.suppliers.joins(:contacts).count).to eq(20)
    expect(organization.organization_memberships.where(user: administrator, status: :active).count).to eq(1)
  end

  it 'reuses an archived demo fiscal regime instead of inserting a duplicate' do
    described_class.seed!
    regime = SatFiscalRegime.active.find_by!(code: '601', person_type: 'M')
    count = SatFiscalRegime.count
    regime.update!(deleted_at: Time.current)

    described_class.seed!

    expect(SatFiscalRegime.count).to eq(count)
    expect(SatFiscalRegime.active.where(code: '601', person_type: 'M')).to exist
    expect(SatFiscalRegime.active.where(code: '601').count).to eq(1)
  end

  it 'does not recreate a manually archived primary supplier contact' do
    described_class.seed!
    supplier = Supplier.find_by!(code: 'SUP-0001')
    contact = supplier.contacts.first
    contact.update!(deleted_at: Time.current)

    described_class.seed!

    expect(supplier.contacts.with_deleted.count).to eq(1)
    expect(supplier.contacts.with_deleted.first.id).to eq(contact.id)
  end

  it 'does not duplicate suppliers, contacts or memberships when run twice' do
    2.times { described_class.seed! }

    organization = Organization.find_by!(tax_id: described_class::ORGANIZATION_TAX_ID)
    expect(organization.suppliers.count).to eq(20)
    expect(Contact.where(contactable: organization.suppliers).count).to eq(20)
    expect(organization.organization_memberships.where(user: administrator).count).to eq(1)
  end
  it 'includes complete demo dossier identity, commercial terms and ownership' do
    described_class.seed!

    organization = Organization.find_by!(tax_id: described_class::ORGANIZATION_TAX_ID)
    supplier = organization.suppliers.find_by!(code: 'SUP-0002')
    expect(supplier).to have_attributes(
      legal_name: 'Comercializadora Demo 2, S.A. de C.V.',
      trade_name: 'Distribuidora Demo 2', alias_name: 'Demo 2',
      credit_days: 30, credit_limit: 20_000, minimum_order_amount: 700
    )
    expect(supplier.classification).to be_present
    expect(supplier.tags).to include('demostracion')
    expect(supplier.responsible_user).to eq(administrator)
    expect(supplier.sat_fiscal_regime.code).to eq('601')
    expect(supplier.contacts.first.mobile_phone).to be_present
    expect(supplier.organization_id).to eq(organization.id)
  end

  it 'completes missing contact and fiscal fields without replacing existing values' do
    described_class.seed!

    supplier = Supplier.find_by!(code: 'SUP-0002')
    supplier.update!(email: nil, phone: nil, postal_code: nil, notes: nil)
    supplier.update!(legal_name: 'Razón social ajustada')

    described_class.seed!

    expect(supplier.reload).to have_attributes(
      legal_name: 'Razón social ajustada',
      email: 'proveedor2@example.com', phone: '+525500000002',
      postal_code: '60002', notes: 'Proveedor de demostración 2 para Delta POS.'
    )
  end

  it 'backfills missing commercial fields but preserves deliberate zero amounts' do
    described_class.seed!
    supplier = Supplier.find_by!(code: 'SUP-0002')
    supplier.update!(credit_limit: 0, discount_percent: 0, responsible_user: nil,
                     minimum_order_amount: 0)

    described_class.seed!

    expect(supplier.reload.credit_limit).to eq(0)
    expect(supplier.discount_percent).to eq(0)
    expect(supplier.minimum_order_amount).to eq(0)
    expect(supplier.responsible_user.email).to eq('administrador@delta.com')
  end

  it 'fills missing details without resetting user-edited supplier records or contacts' do
    described_class.seed!

    organization = Organization.find_by!(tax_id: described_class::ORGANIZATION_TAX_ID)
    supplier = organization.suppliers.find_by!(code: 'SUP-0001')
    contact = supplier.contacts.first
    supplier.update!(legal_name: 'Empresa editada, S.A.', status: :inactive,
                     credit_days: 0, tags: ['cliente-frecuente'])
    contact.update!(name: 'Contacto modificado', email: 'editado@example.com', primary: false)
    supplier.update!(alias_name: nil)

    described_class.seed!

    expect(supplier.reload).to have_attributes(
      legal_name: 'Empresa editada, S.A.', status: 'inactive',
      credit_days: 0, alias_name: 'Demo 1', tags: ['cliente-frecuente']
    )
    expect(contact.reload.name).to eq('Contacto modificado')
    expect(contact.email).to eq('editado@example.com')
    expect(supplier.contacts.count).to eq(1)
  end
end
