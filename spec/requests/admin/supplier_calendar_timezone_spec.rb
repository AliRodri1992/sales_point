# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier calendar organization time zone', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  it 'shows the supplier calendar when onboarding has not established a time zone yet' do
    get admin_supplier_path(supplier, tab: 'schedules')

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('section[data-section="schedules"]')).to be_present
  end

  it 'shows an event on the local organization date instead of the UTC date' do
    create(:organization_setting, organization:, timezone: 'America/Mexico_City')
    branch = create(:branch, organization:)
    supplier.supplier_events.create!(
      branch:, title: 'Evening receipt', kind: 'delivery',
      starts_at: Time.utc(2026, 10, 23, 1), ends_at: Time.utc(2026, 10, 23, 3)
    )

    get admin_supplier_path(supplier, tab: 'schedules', calendar_month: '2026-10',
                                      calendar_selected_day: '2026-10-22')

    expect(response).to have_http_status(:ok)
    panel = Nokogiri::HTML(response.body).at_css('section[data-section="schedules"]')
    expect(panel.at_css('[data-calendar-date="2026-10-22"]').text).to include('Evening receipt')
    expect(panel.at_css('[data-calendar-day-details]').text).to include('Evening receipt')
  end
end
