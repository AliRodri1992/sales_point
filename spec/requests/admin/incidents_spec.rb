require 'rails_helper'

RSpec.describe 'Incident reporting', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, user: user, organization: organization)
    sign_in user
  end

  it 'opens the form and records an optional impact as unknown' do
    get new_admin_incident_path
    expect(response).to have_http_status(:ok)
    post admin_incidents_path, params: { incident: { description: 'Screen failed' } }, as: :json
    expect(response).to have_http_status(:created)
    incident = Incident.find_by!(reporter: user)
    expect(incident.folio).to match(/\AInc\d{18}\z/)
    expect(incident.blocks_operation).to be_nil
    get response.parsed_body.fetch('url')
    expect(response).to have_http_status(:ok)
  end

  it 'returns the original folio when a browser retries a submission' do
    payload = { incident: { description: 'Retry', submission_key: SecureRandom.uuid } }
    expect do
      2.times { post admin_incidents_path, params: payload, as: :json }
    end.to change(Incident, :count).by(1)
    expect(response.parsed_body.fetch('url')).to eq(admin_incident_path(Incident.last))
  end

  it 'increments the daily sequence across organizations and restarts it the next day' do
    Time.use_zone(Rails.application.config.time_zone) do
      travel_to(Time.zone.local(2026, 11, 26, 8, 41))
      first = Incident.create!(organization: organization, reporter: user, description: 'First')
      second = Incident.create!(organization: create(:organization), reporter: user, description: 'Second')
      expect(first.folio).to eq('Inc202611260841000001')
      expect(second.folio).to eq('Inc202611260841000002')
      travel 1.day
      expect(Incident.create!(organization: organization, reporter: user, description: 'Third').folio)
        .to eq('Inc202611270841000001')
    ensure
      travel_back
    end
  end

  it 'rejects missing descriptions without allocating a number' do
    expect do
      post admin_incidents_path, params: { incident: { description: ' ' } }, as: :json
    end.not_to change(Incident, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'hides reports from other organizations' do
    incident = Incident.create!(organization: create(:organization), reporter: create(:user),
                                description: 'Other store')
    get admin_incident_path(incident)
    expect(response).to have_http_status(:not_found)
  end
end
