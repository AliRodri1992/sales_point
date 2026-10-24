# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin supplier schedules', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: admin_role)
    sign_in user
  end

  def schedule_attributes(overrides = {})
    { branch_id: branch.id, kind: 'visit', weekday: 1,
      starts_at: '09:00', ends_at: '11:00', notes: 'Weekly visit' }.merge(overrides)
  end

  it 'renders the new and edit screens for recurring supplier schedules' do
    get new_admin_supplier_schedule_path(supplier)
    expect(response).to have_http_status(:ok)

    schedule = supplier.supplier_schedules.create!(schedule_attributes.except(:branch_id).merge(branch:))
    get edit_admin_supplier_schedule_path(supplier, schedule)
    expect(response).to have_http_status(:ok)
  end

  it 'blocks new recurring schedules when the supplier is inactive' do
    supplier.update!(status: :inactive)

    post admin_supplier_schedules_path(supplier),
         params: { supplier_schedule: schedule_attributes }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(supplier.supplier_schedules.count).to eq(0)
  end

  it 'renders errors when editing an existing schedule to an invalid range' do
    schedule = supplier.supplier_schedules.create!(schedule_attributes.except(:branch_id).merge(branch:))
    patch admin_supplier_schedule_path(supplier, schedule),
          params: { supplier_schedule: schedule_attributes(starts_at: '17:00', ends_at: '09:00') }

    expect(response).to have_http_status(:unprocessable_content)
    expect(schedule.reload.starts_at.strftime('%H:%M')).to eq('09:00')
  end

  it 'creates a branch visit and displays it in the supplier dossier' do
    expect do
      post admin_supplier_schedules_path(supplier),
           params: { supplier_schedule: schedule_attributes }
    end.to change(SupplierSchedule, :count).by(1)

    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    schedule = supplier.supplier_schedules.last
    expect(schedule.branch).to eq(branch)
    expect(schedule.kind).to eq('visit')

    get admin_supplier_path(supplier, tab: 'schedules')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(branch.name, 'Weekly visit')
  end

  it 'returns to supplier calendars after creating a schedule from the dossier' do
    post admin_supplier_schedules_path(supplier), params: {
      return_to: 'dossier', supplier_schedule: schedule_attributes
    }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
  end

  it 'rejects modifications and restoration when the supplier is inactive' do
    schedule = supplier.supplier_schedules.create!(
      branch:, kind: 'delivery', weekday: 2, starts_at: '10:00', ends_at: '12:00'
    )
    supplier.update!(status: :inactive)
    patch admin_supplier_schedule_path(supplier, schedule),
          params: { supplier_schedule: schedule_attributes(starts_at: '13:00') }
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(schedule.reload.starts_at.strftime('%H:%M')).to eq('10:00')

    schedule.update!(deleted_at: Time.current)
    patch restore_admin_supplier_schedule_path(supplier, schedule)
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(schedule.reload.deleted_at).to be_present
  end

  it 'updates an existing delivery schedule' do
    schedule = SupplierSchedule.create!(supplier:, branch:, kind: 'delivery',
                                        weekday: 2, starts_at: '10:00', ends_at: '12:00')
    patch admin_supplier_schedule_path(supplier, schedule),
          params: { supplier_schedule: schedule_attributes(kind: 'order', weekday: 4) }

    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    expect(schedule.reload).to have_attributes(kind: 'order', weekday: 4)
  end

  it 'retains entered data and shows individual errors when times are invalid' do
    post admin_supplier_schedules_path(supplier),
         params: { supplier_schedule: schedule_attributes(starts_at: '15:00', ends_at: '09:00') }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('15:00', '09:00')
    expect(response.body).to include('data-server-field-error')
    expect(supplier.supplier_schedules.count).to eq(0)
  end

  it 'rejects a branch from a different organization' do
    other_branch = create(:branch, organization: create(:organization))
    post admin_supplier_schedules_path(supplier),
         params: { supplier_schedule: schedule_attributes(branch_id: other_branch.id) }

    expect(response).to have_http_status(:unprocessable_content)
    expect(supplier.supplier_schedules.count).to eq(0)
  end

  it 'cannot access schedules belonging to another organization' do
    other_supplier = create(:supplier, organization: create(:organization))
    get admin_supplier_schedules_path(other_supplier)

    expect(response).to have_http_status(:not_found)
  end
end
