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

  it 'paginates exceptions and allows bulk archiving and restoration' do
    exceptions = Array.new(23) do |index|
      supplier.supplier_schedule_exceptions.create!(
        starts_on: Date.current + index.days, reason: 'holiday', created_by: user
      )
    end
    get admin_supplier_schedules_path(supplier)
    expect(Nokogiri::HTML(response.body).css('input[name="exception_ids[]"]').size).to eq(20)
    get admin_supplier_schedules_path(supplier, page: 2)
    expect(Nokogiri::HTML(response.body).css('input[name="exception_ids[]"]').size).to eq(3)

    ids = exceptions.first(2).map(&:id)
    patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
          params: { exception_ids: ids, operation: 'archive' }
    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    expect(supplier.supplier_schedule_exceptions.where(id: ids)).to be_empty

    patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
          params: { exception_ids: ids, operation: 'restore' }
    expect(response).to redirect_to(admin_supplier_schedules_path(supplier, archived: '1'))
    expect(supplier.supplier_schedule_exceptions.where(id: ids).count).to eq(2)
  end

  it 'rejects cross-supplier ids without changing any exceptions' do
    own = supplier.supplier_schedule_exceptions.create!(starts_on: Date.current, reason: 'holiday')
    outsider = create(:supplier, organization:)
    foreign = outsider.supplier_schedule_exceptions.create!(starts_on: Date.current, reason: 'holiday')
    patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
          params: { exception_ids: [own.id, foreign.id], operation: 'archive' }
    expect(response).to have_http_status(:not_found)
    expect(own.reload.deleted_at).to be_nil
    expect(foreign.reload.deleted_at).to be_nil
  end

  it 'prevents editing and bulk restoration for an inactive supplier' do
    exception = supplier.supplier_schedule_exceptions.create!(
      starts_on: Date.current, reason: 'holiday'
    )
    exception.update!(deleted_at: Time.current)
    supplier.update!(status: :inactive)

    patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
          params: { exception_ids: [exception.id], operation: 'restore' }
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(exception.reload.deleted_at).to be_present

    patch admin_supplier_schedule_exception_path(supplier, exception),
          params: { supplier_schedule_exception: { reason: 'suspension' } }
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(exception.reload.reason).to eq('holiday')
  end

  it 'updates an exception scoped to a specific recurring supplier schedule' do
    branch = create(:branch, organization:)
    schedule = supplier.supplier_schedules.create!(
      branch:, kind: 'delivery', weekday: Date.current.wday,
      starts_at: '09:00', ends_at: '11:00'
    )
    exception = supplier.supplier_schedule_exceptions.create!(
      starts_on: Date.current, reason: 'holiday'
    )
    patch admin_supplier_schedule_exception_path(supplier, exception),
          params: { supplier_schedule_exception: {
            reason: 'suspension', starts_on: Date.current, supplier_schedule_id: schedule.id
          } }

    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    expect(exception.reload).to have_attributes(supplier_schedule_id: schedule.id, reason: 'suspension')
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
