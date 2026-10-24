# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier restore lifecycle failures', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }
  let(:supplier) { create(:supplier, organization:, deleted_at: Time.current, status: :inactive) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  it 'keeps archived suppliers untouched when restoration fails validation' do
    supplier
    allow_any_instance_of(Supplier).to receive(:update).and_return(false)

    patch restore_admin_supplier_path(supplier)

    expect(response).to redirect_to(admin_suppliers_path(archived: '1'))
    expect(flash[:alert]).to be_present
    expect(Supplier.with_deleted.find(supplier.id).deleted_at).to be_present
  end

  it 'returns an actionable conflict without restoring another suppliers identity' do
    supplier
    allow_any_instance_of(Supplier).to receive(:update).and_raise(ActiveRecord::RecordNotUnique)

    patch restore_admin_supplier_path(supplier)

    expect(response).to redirect_to(admin_suppliers_path(archived: '1'))
    expect(flash[:alert]).to be_present
    expect(Supplier.with_deleted.find(supplier.id).deleted_at).to be_present
  end

  it 'never restores an archived supplier from another organization' do
    foreign = create(:supplier, organization: create(:organization), deleted_at: Time.current,
                                status: :inactive)

    patch restore_admin_supplier_path(foreign)

    expect(response).to have_http_status(:not_found)
    expect(Supplier.with_deleted.find(foreign.id).deleted_at).to be_present
  end
end
