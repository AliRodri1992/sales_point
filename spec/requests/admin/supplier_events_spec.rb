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

  it 'creates a dated event and displays it in the dossier calendar' do
    expect do
      post admin_supplier_events_path(supplier), params: { supplier_event: attributes }
    end.to change(SupplierEvent, :count).by(1)

    event = supplier.supplier_events.last
    expect(event).to have_attributes(title: 'Extra delivery', kind: 'delivery', created_by: user)
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))

    get admin_supplier_path(supplier, tab: 'schedules', calendar_month: '2026-10')
    panel = Nokogiri::HTML(response.body).at_css('section[data-section="schedules"]')
    expect(panel.css('[data-calendar-date="2026-10-23"]').first.text).to include('Extra delivery')
    expect(panel.at_css("[data-calendar-event='#{event.id}']")).to be_present
  end

  it 'updates and archives an event without removing its audit record' do
    event = supplier.supplier_events.create!(attributes.except(:branch_id).merge(branch:, created_by: user))
    patch admin_supplier_event_path(supplier, event),
          params: { supplier_event: attributes(title: 'New title') }
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
    expect(event.reload.title).to eq('New title')

    delete admin_supplier_event_path(supplier, event)
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'schedules'))
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
