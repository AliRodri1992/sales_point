# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier dated events', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def attributes(overrides = {})
    { title: 'Extra delivery', kind: 'delivery', branch_id: branch.id,
      starts_at: '2026-10-23T09:00', ends_at: '2026-10-23T11:00', notes: 'Bring samples' }.merge(overrides)
  end

  def calendar_destination
    params = { tab: 'schedules', calendar_month: '2026-10', calendar_selected_day: '2026-10-23' }
    admin_supplier_path(supplier, params)
  end

  it 'creates a dated event and displays it in the dossier calendar' do
    expect do
      post admin_supplier_events_path(supplier), params: { supplier_event: attributes }
    end.to change(SupplierEvent, :count).by(1)

    event = supplier.supplier_events.last
    expect(event).to have_attributes(title: 'Extra delivery', kind: 'delivery', created_by: user)
    expect(response).to redirect_to(calendar_destination)

    get admin_supplier_path(supplier, tab: 'schedules', calendar_month: '2026-10')
    panel = Nokogiri::HTML(response.body).at_css('section[data-section="schedules"]')
    expect(panel.css('[data-calendar-date="2026-10-23"]').first.text).to include('Extra delivery')
    expect(panel.at_css("[data-calendar-event='#{event.id}']")).to be_present
  end

  it 'updates and archives an event without removing its audit record' do
    event = supplier.supplier_events.create!(attributes.except(:branch_id).merge(branch:, created_by: user))
    patch admin_supplier_event_path(supplier, event),
          params: { supplier_event: attributes(title: 'New title') }
    expect(response).to redirect_to(calendar_destination)
    expect(event.reload.title).to eq('New title')

    delete admin_supplier_event_path(supplier, event)
    expect(response).to redirect_to(calendar_destination)
    expect(event.reload.deleted_at).to be_present
    expect(supplier.supplier_events.not_deleted).to be_empty
  end

  it 'shows errors for an invalid end time and preserves entered values' do
    post admin_supplier_events_path(supplier),
         params: { supplier_event: attributes(ends_at: '2026-10-23T08:00') }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Extra delivery', 'data-server-field-error')
    expect(supplier.supplier_events.count).to eq(0)
  end

  it 'rejects a branch from another organization' do
    foreign_branch = create(:branch, organization: create(:organization))
    post admin_supplier_events_path(supplier),
         params: { supplier_event: attributes(branch_id: foreign_branch.id) }
    expect(response).to have_http_status(:unprocessable_content)
    expect(supplier.supplier_events.count).to eq(0)
  end

  it 'cannot create events for a foreign supplier' do
    other = create(:supplier, organization: create(:organization))
    post admin_supplier_events_path(other), params: { supplier_event: attributes }
    expect(response).to have_http_status(:not_found)
  end

  it 'recovers an archived event from the supplier dossier without duplicating it' do
    event = supplier.supplier_events.create!(attributes.except(:branch_id).merge(branch:, created_by: user))
    event.update!(deleted_at: Time.current)

    get admin_supplier_path(supplier, tab: 'schedules', calendar_month: '2026-10')
    panel = Nokogiri::HTML(response.body).at_css('section[data-section="schedules"]')
    expect(panel.at_css('[data-calendar-archived]')).to be_present
    expect(panel.at_css("form[action='#{restore_admin_supplier_event_path(supplier, event)}']")).to be_present
    expect(panel.css("[data-calendar-event='#{event.id}']")).to be_empty

    expect do
      patch restore_admin_supplier_event_path(supplier, event)
    end.to change { supplier.supplier_events.not_deleted.count }.by(1)
       .and not_change { supplier.supplier_events.with_deleted.count }

    expect(response).to redirect_to(calendar_destination)
    expect(event.reload.deleted_at).to be_nil
  end

  it 'rejects restoration of events owned by another supplier' do
    other = create(:supplier, organization:)
    event = other.supplier_events.create!(title: 'Archived', kind: 'visit', branch:,
                                          starts_at: Time.zone.local(2026, 10, 23, 10),
                                          deleted_at: Time.current)
    patch restore_admin_supplier_event_path(supplier, event)

    expect(response).to have_http_status(:not_found)
    expect(event.reload.deleted_at).to be_present
  end

  it 'shows all activities for a selected day even when the grid overflows' do
    5.times do |index|
      supplier.supplier_events.create!(title: "Activity #{index + 1}", branch:, kind: 'visit',
                                       starts_at: Time.zone.local(2026, 10, 23, 9 + index))
    end

    calendar_params = { tab: 'schedules', calendar_month: '2026-10',
                        calendar_selected_day: '2026-10-23' }
    get admin_supplier_path(supplier, calendar_params)

    panel = Nokogiri::HTML(response.body).at_css('section[data-section="schedules"]')
    selected_day = panel.at_css('[data-calendar-day-details]')
    expect(selected_day.css('[data-day-item="event"]').size).to eq(5)
    expect(panel.at_css('[data-calendar-date="2026-10-23"]').css('a').map(&:text).join)
      .to include('2 more')
    expect(panel.at_css('[data-calendar-day-details] button[data-date="2026-10-23"]')).to be_present
  end

  it 'shows monthly and weekly navigation, filtering and a creation drawer' do
    calendar_params = {
      tab: 'schedules', calendar_view: 'week', calendar_day: '2026-10-23', calendar_kind: 'visit'
    }
    get admin_supplier_path(supplier, calendar_params)

    panel = Nokogiri::HTML(response.body).at_css('section[data-section="schedules"]')
    expect(panel.css('[data-calendar-date]').size).to eq(7)
    expect(panel.at_css('[data-supplier-calendar-target="drawer"]')).to be_present
    expect(panel.at_css("form[action='#{admin_supplier_events_path(supplier)}']")).to be_present
    expect(panel.at_css("a[href='#{admin_supplier_schedules_path(supplier)}']")).to be_present
  end
end
