# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier catalog failure and recovery paths', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user: actor)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in actor
  end

  it 'renders a safe error after duplicate organization contact insertion' do
    allow_any_instance_of(Contact).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
    post admin_organization_contacts_path, params: { contact: { name: 'Finance' } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'renders a safe error after duplicate organization contact update' do
    record = create(:contact, contactable: organization)
    allow_any_instance_of(Contact).to receive(:update).and_raise(ActiveRecord::RecordNotUnique)
    patch admin_organization_contact_path(record), params: { contact: { name: 'Updated' } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'redirects when a deleted organization contact cannot be restored' do
    record = create(:contact, :deleted, contactable: organization)
    allow_any_instance_of(Contact).to receive(:restore_safely).and_return(false)
    patch restore_admin_organization_contact_path(record)
    expect(response).to redirect_to(admin_organization_contacts_path)
  end

  it 'handles a duplicate supplier contact insertion' do
    allow_any_instance_of(Contact).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
    post admin_supplier_contacts_path(supplier), params: { contact: { name: 'Sales' } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'handles a duplicate supplier contact update' do
    record = create(:contact, contactable: supplier)
    allow_any_instance_of(Contact).to receive(:update).and_raise(ActiveRecord::RecordNotUnique)
    patch admin_supplier_contact_path(supplier, record), params: { contact: { name: 'Sales' } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects restoring an invalid archived supplier contact' do
    record = create(:contact, :deleted, contactable: supplier)
    allow_any_instance_of(Contact).to receive(:restore_safely).and_return(false)
    patch restore_admin_supplier_contact_path(supplier, record)
    expect(response).to redirect_to(admin_supplier_contacts_path(supplier))
  end

  it 'renders a safe error after duplicate supplier address insertion' do
    allow_any_instance_of(Address).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)
    post admin_supplier_addresses_path(supplier), params: {
      address: { street: 'Main', city: 'Mexico City', state: 'CDMX', postal_code: '06000' }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'renders a safe error after duplicate supplier address update' do
    record = create(:address, addressable: supplier)
    allow_any_instance_of(Address).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)
    patch admin_supplier_address_path(supplier, record), params: {
      address: { street: 'Updated' }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'redirects after a supplier address fails safe restoration' do
    record = create(:address, :deleted, addressable: supplier)
    allow_any_instance_of(Address).to receive(:restore_safely).and_return(false)
    patch restore_admin_supplier_address_path(supplier, record)
    expect(response).to redirect_to(admin_supplier_addresses_path(supplier))
  end

  it 'renders supplier offer validation failures after duplicate database insertions' do
    allow_any_instance_of(SupplierProduct).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
    product = create(:product, organization:)
    post admin_supplier_supplier_products_path(supplier), params: {
      supplier_product: {
        product_id: product.id, currency_id: supplier.currency.id,
        presentation_name: 'Unit', purchase_price: 10, units_per_package: 1, minimum_quantity: 1
      }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects a duplicate supplier offer update without corrupting existing prices' do
    product = create(:product, organization:)
    offer = SupplierProduct.create!(
      organization:, supplier:, product:, currency: supplier.currency, presentation_name: 'Unit',
      units_per_package: 1, purchase_price: 10, minimum_quantity: 1
    )
    allow_any_instance_of(SupplierProduct).to receive(:update).and_raise(ActiveRecord::RecordNotUnique)
    patch admin_supplier_supplier_product_path(supplier, offer), params: {
      supplier_product: { purchase_price: 100 }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(offer.reload.purchase_price).to eq(10)
  end

  it 'renders supplier schedules update errors for invalid weekdays' do
    branch = create(:branch, organization:)
    schedule = SupplierSchedule.create!(supplier:, branch:, kind: 'visit', weekday: 1, starts_at: '09:00')
    patch admin_supplier_schedule_path(supplier, schedule), params: {
      supplier_schedule: { weekday: 9 }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(schedule.reload.weekday).to eq(1)
  end

  it 'returns to the schedules list if safe restoration is rejected' do
    branch = create(:branch, organization:)
    schedule = SupplierSchedule.create!(supplier:, branch:, kind: 'visit', weekday: 1, starts_at: '09:00')
    schedule.update!(deleted_at: Time.current)
    allow_any_instance_of(SupplierSchedule).to receive(:restore_safely).and_return(false)
    patch restore_admin_supplier_schedule_path(supplier, schedule)
    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
  end
end
