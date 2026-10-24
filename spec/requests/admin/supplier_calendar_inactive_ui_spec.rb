# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inactive supplier calendar actions', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  it 'hides new, edit and restore actions without hiding historical cleanup' do
    schedule = supplier.supplier_schedules.create!(
      branch:, kind: 'visit', weekday: Date.current.wday, starts_at: '09:00', ends_at: '10:00'
    )
    event = supplier.supplier_events.create!(
      branch:, kind: 'visit', title: 'Historical visit', starts_at: Time.zone.now
    )
    archived = supplier.supplier_events.create!(
      branch:, kind: 'visit', title: 'Archived visit', starts_at: Time.zone.now
    )
    archived.update!(deleted_at: Time.current)
    supplier.update!(status: :inactive)

    get admin_supplier_path(supplier, tab: 'schedules')
    expect(response).to have_http_status(:ok)

    panel = Nokogiri::HTML(response.body).at_css('section[data-section="schedules"]')
    expect(panel.at_css('[data-supplier-calendar-target="drawer"]')).to be_nil
    expect(panel.css('button[data-action="supplier-calendar#open"]')).to be_empty
    expect(panel.css("a[href='#{edit_admin_supplier_schedule_path(supplier, schedule, return_to: 'dossier')}']"))
      .to be_empty
    expect(panel.css("a[href='#{edit_admin_supplier_event_path(supplier, event)}']")).to be_empty
    expect(panel.css("form[action='#{restore_admin_supplier_event_path(supplier, archived)}']")).to be_empty
    expect(panel.css("form[action='#{admin_supplier_event_path(supplier, event)}']")).not_to be_empty
  end
end
