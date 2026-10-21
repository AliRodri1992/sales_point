# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier schedule exceptions', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  it 'creates and removes a delivery suspension' do
    post admin_supplier_schedule_exceptions_path(supplier), params: {
      supplier_schedule_exception: { starts_on: Date.current, ends_on: Date.tomorrow,
                                     reason: 'suspension' }
    }
    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    exception = supplier.supplier_schedule_exceptions.last
    expect(exception.created_by).to eq(user)

    delete admin_supplier_schedule_exception_path(supplier, exception)
    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    expect(exception.class.exists?(exception.id)).to be(false)
  end
end
