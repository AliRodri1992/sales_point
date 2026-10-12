# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier schedule restoration', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  it 'restores a soft-deleted schedule' do
    schedule = SupplierSchedule.create!(supplier:, branch:, kind: 'visit', weekday: 1, starts_at: '09:00')
    schedule.update!(deleted_at: Time.current)

    patch restore_admin_supplier_schedule_path(supplier, schedule)

    expect(response).to redirect_to(admin_supplier_schedules_path(supplier))
    expect(schedule.reload.deleted_at).to be_nil
  end

  it 'does not restore a schedule belonging to another organization' do
    foreign_org = create(:organization)
    foreign_supplier = create(:supplier, organization: foreign_org)
    foreign_branch = create(:branch, organization: foreign_org)
    schedule = SupplierSchedule.create!(
      supplier: foreign_supplier, branch: foreign_branch,
      kind: 'visit', weekday: 1, starts_at: '09:00', deleted_at: Time.current
    )

    patch restore_admin_supplier_schedule_path(foreign_supplier, schedule)

    expect(response).to have_http_status(:not_found)
    expect(schedule.reload.deleted_at).to be_present
  end
end
