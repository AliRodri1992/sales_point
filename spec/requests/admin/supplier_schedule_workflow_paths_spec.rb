# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier recurring calendar workflow paths', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:user) { create(:user, :english) }
  let(:weekday) { Date.current.wday }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def params_for_schedule(overrides = {})
    { branch_id: branch.id, kind: 'visit', weekday:,
      starts_at: '09:00', ends_at: '10:00' }.merge(overrides)
  end

  it 'creates a recurring event and returns to the supplier dossier' do
    post admin_supplier_schedules_path(supplier), params: {
      return_to: 'dossier', supplier_schedule: params_for_schedule
    }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(supplier.supplier_schedules.not_deleted.count).to eq(1)
  end

  it 'displays validation errors instead of saving an inverted time range' do
    post admin_supplier_schedules_path(supplier), params: {
      supplier_schedule: params_for_schedule(ends_at: '08:00')
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(supplier.supplier_schedules.not_deleted.count).to eq(0)
  end

  it 'updates a recurring event and returns to the supplier dossier' do
    schedule = supplier.supplier_schedules.create!(params_for_schedule)
    patch admin_supplier_schedule_path(supplier, schedule), params: {
      return_to: 'dossier', supplier_schedule: { starts_at: '10:00', ends_at: '11:00' }
    }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(schedule.reload.starts_at.strftime('%H:%M')).to eq('10:00')
  end

  it 'keeps a recurring schedule unchanged when the requested update is invalid' do
    schedule = supplier.supplier_schedules.create!(params_for_schedule)
    patch admin_supplier_schedule_path(supplier, schedule), params: {
      supplier_schedule: { starts_at: '11:00', ends_at: '10:00' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(schedule.reload.starts_at.strftime('%H:%M')).to eq('09:00')
  end

  it 'allows viewing archived calendar exceptions separately from active ones' do
    exception = supplier.supplier_schedule_exceptions.create!(
      reason: 'suspension', starts_on: Date.current, deleted_at: Time.current
    )

    get admin_supplier_schedules_path(supplier, archived: '1')

    expect(response).to have_http_status(:ok)
    expect(exception.reload.deleted_at).to be_present
  end

  it 'does not permit new recurring schedules on inactive suppliers' do
    supplier.update!(status: :inactive)

    get new_admin_supplier_schedule_path(supplier)

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
  end
end
