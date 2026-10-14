# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier and organization catalog controller paths', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:actor) { create(:user, :english) }

  before do
    create(:organization_membership, user: actor, organization:)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in actor
  end

  def offer_attributes
    {
      product_id: product.id, presentation_name: 'Box', currency_id: supplier.currency.id,
      units_per_package: 12, purchase_price: 100, minimum_quantity: 1,
      discount_percent: 0, freight_amount: 0, nonrecoverable_tax: 0, lead_time_days: 2
    }
  end

  def offer
    SupplierProduct.create!(offer_attributes.except(:product_id, :currency_id)
      .merge(organization:, supplier:, product:, currency: supplier.currency))
  end

  it 'renders the supplier product offer creation form' do
    get new_admin_supplier_supplier_product_path(supplier)
    expect(response).to have_http_status(:ok)
  end

  it 'renders the supplier product offer edit form' do
    get edit_admin_supplier_supplier_product_path(supplier, offer)
    expect(response).to have_http_status(:ok)
  end

  it 'shows price change history' do
    get history_admin_supplier_supplier_product_path(supplier, offer)
    expect(response).to have_http_status(:ok)
  end

  it 'updates supplier-specific purchase prices and records history' do
    record = offer
    patch admin_supplier_supplier_product_path(supplier, record), params: {
      supplier_product: { purchase_price: 120, lead_time_days: 3 }
    }
    expect(response).to redirect_to(admin_supplier_supplier_products_path(supplier))
    expect(record.reload.purchase_price).to eq(120)
  end

  it 'rejects invalid supplier offer prices without losing the form' do
    record = offer
    patch admin_supplier_supplier_product_path(supplier, record), params: {
      supplier_product: { purchase_price: -5 }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(record.reload.purchase_price).to eq(100)
  end

  it 'rejects creating a supplier offer with a negative price' do
    post admin_supplier_supplier_products_path(supplier), params: {
      supplier_product: offer_attributes.merge(purchase_price: -5)
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'soft deletes a supplier product without losing its price history' do
    record = offer
    delete admin_supplier_supplier_product_path(supplier, record)
    expect(response).to redirect_to(admin_supplier_supplier_products_path(supplier))
    expect(record.reload.deleted_at).to be_present
  end

  it 'lists organization contacts' do
    get admin_organization_contacts_path
    expect(response).to have_http_status(:ok)
  end

  it 'renders the new organization contact form' do
    get new_admin_organization_contact_path
    expect(response).to have_http_status(:ok)
  end

  it 'renders editing an organization contact' do
    contact = create(:contact, contactable: organization)
    get edit_admin_organization_contact_path(contact)
    expect(response).to have_http_status(:ok)
  end

  it 'updates an organization contact' do
    contact = create(:contact, contactable: organization)
    patch admin_organization_contact_path(contact), params: { contact: { name: 'Updated manager' } }
    expect(response).to redirect_to(admin_organization_contacts_path)
    expect(contact.reload.name).to eq('Updated manager')
  end

  it 'does not persist invalid organization contacts' do
    post admin_organization_contacts_path, params: { contact: { name: '' } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects invalid organization contact updates' do
    contact = create(:contact, contactable: organization)
    patch admin_organization_contact_path(contact), params: { contact: { name: '' } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'restores archived organization contacts' do
    contact = create(:contact, :deleted, contactable: organization)
    patch restore_admin_organization_contact_path(contact)
    expect(response).to redirect_to(admin_organization_contacts_path)
    expect(contact.reload.deleted_at).to be_nil
  end

  it 'rejects unknown supplier export format' do
    get export_admin_suppliers_path, params: { file_format: 'invalid' }
    expect(response).to have_http_status(:bad_request)
  end

  %w[pdf xlsx].each do |format|
    it "exports only organization suppliers in #{format}" do
      supplier
      allow(Reports::ExportService).to receive(:call).and_return('test-file')
      get export_admin_suppliers_path, params: { file_format: format }
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('test-file')
      expect(Reports::ExportService).to have_received(:call).with(
        report: an_instance_of(Reports::Definitions::SuppliersReport), format:
      )
    end
  end
end
