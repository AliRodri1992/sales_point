# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier calendar validation paths', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  def create_exception(overrides = {})
    supplier.supplier_schedule_exceptions.create!(
      { starts_on: Date.current, reason: 'holiday', created_by: user }.merge(overrides)
    )
  end

  def recurring_schedule(overrides = {})
    supplier.supplier_schedules.create!(
      { branch:, kind: 'visit', weekday: Date.current.wday,
        starts_at: '09:00', ends_at: '10:00' }.merge(overrides)
    )
  end

  it 'rejects empty exception bulk operations' do
    patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
          params: { exception_ids: [], operation: 'archive' }
    expect(response).to have_http_status(:bad_request)
  end

  it 'rejects unknown exception bulk operations' do
    exception = create_exception
    patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
          params: { exception_ids: [exception.id], operation: 'delete_all' }
    expect(response).to have_http_status(:bad_request)
    expect(exception.reload.deleted_at).to be_nil
  end

  it 'rejects malformed and over-limit exception bulk selections' do
    %w[0 1=1].each do |id|
      patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
            params: { exception_ids: [id], operation: 'archive' }
      expect(response).to have_http_status(:bad_request)
    end

    patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
          params: { exception_ids: (1..101).to_a, operation: 'archive' }
    expect(response).to have_http_status(:bad_request)
  end

  it 'rejects invalid exception creation with an actionable error' do
    post admin_supplier_schedule_exceptions_path(supplier), params: {
      supplier_schedule_exception: { starts_on: Date.current, reason: 'not_a_reason' }
    }
    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    expect(flash[:alert]).to be_present
    expect(supplier.supplier_schedule_exceptions.count).to be_zero
  end

  it 'renders the exception editor and refuses an invalid date range' do
    exception = create_exception
    get edit_admin_supplier_schedule_exception_path(supplier, exception)
    expect(response).to have_http_status(:ok)

    patch admin_supplier_schedule_exception_path(supplier, exception),
          params: { supplier_schedule_exception: {
            starts_on: Date.current, ends_on: Date.yesterday, reason: 'holiday'
          } }
    expect(response).to redirect_to(edit_admin_supplier_schedule_exception_path(supplier, exception))
    expect(exception.reload.ends_on).to be_nil
  end

  it 'archives only selected exceptions and refuses unknown restoration ids' do
    exception = create_exception
    patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
          params: { exception_ids: [exception.id], operation: 'archive' }
    expect(exception.reload.deleted_at).to be_present

    patch bulk_update_admin_supplier_schedule_exceptions_path(supplier),
          params: { exception_ids: [exception.id, 9_999_999], operation: 'restore' }
    expect(response).to have_http_status(:not_found)
    expect(exception.reload.deleted_at).to be_present
  end

  it 'restores an archived recurring schedule when there is no conflict' do
    schedule = recurring_schedule
    schedule.update!(deleted_at: Time.current)

    patch restore_admin_supplier_schedule_path(supplier, schedule)
    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    expect(schedule.reload.deleted_at).to be_nil
  end

  it 'does not restore a schedule over a currently active time slot' do
    old = recurring_schedule
    old.update!(deleted_at: Time.current)
    recurring_schedule

    patch restore_admin_supplier_schedule_path(supplier, old)
    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    expect(old.reload.deleted_at).to be_present
    expect(flash[:alert]).to be_present
  end

  it 'rejects restoration of a schedule that is not archived' do
    schedule = recurring_schedule
    patch restore_admin_supplier_schedule_path(supplier, schedule)
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects invalid event updates without altering persisted event dates' do
    event = supplier.supplier_events.create!(
      branch:, kind: 'visit', title: 'Monthly delivery',
      starts_at: Time.zone.local(2026, 10, 23, 9), ends_at: Time.zone.local(2026, 10, 23, 10)
    )
    patch admin_supplier_event_path(supplier, event), params: {
      supplier_event: { ends_at: '2026-10-23T08:00' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(event.reload.ends_at.in_time_zone.hour).to eq(10)
  end

  it 'rejects creating events for inactive suppliers without touching historical entries' do
    event = supplier.supplier_events.create!(
      branch:, kind: 'visit', title: 'Historical', starts_at: 1.day.from_now
    )
    supplier.update!(status: :inactive)

    get new_admin_supplier_event_path(supplier)
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(event.reload.title).to eq('Historical')
  end

  it 'converts a PostgreSQL overlap error into a validation response on schedule creation' do
    recurring_schedule
    allow_any_instance_of(Suppliers::ScheduleConflict).to receive(:exists?).and_return(false)

    expect do
      post admin_supplier_schedules_path(supplier), params: {
        supplier_schedule: {
          branch_id: branch.id, kind: 'visit', weekday: Date.current.wday,
          starts_at: '09:30', ends_at: '10:30'
        }
      }
    end.not_to change(SupplierSchedule.not_deleted, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('09:30')
  end

  it 'converts a PostgreSQL overlap error into a validation response on schedule update' do
    recurring_schedule
    other = supplier.supplier_schedules.create!(
      branch:, kind: 'visit', weekday: Date.current.wday,
      starts_at: '11:00', ends_at: '12:00'
    )
    allow_any_instance_of(Suppliers::ScheduleConflict).to receive(:exists?).and_return(false)

    patch admin_supplier_schedule_path(supplier, other), params: {
      supplier_schedule: { starts_at: '09:30', ends_at: '10:30' }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(other.reload.starts_at.strftime('%H:%M')).to eq('11:00')
  end

  it 'blocks creating new recurring schedules for inactive suppliers' do
    supplier.update!(status: :inactive)
    post admin_supplier_schedules_path(supplier), params: {
      supplier_schedule: {
        branch_id: branch.id, kind: 'visit', weekday: Date.current.wday,
        starts_at: '09:00', ends_at: '10:00'
      }
    }

    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(supplier.supplier_schedules.count).to eq(0)
  end
end
