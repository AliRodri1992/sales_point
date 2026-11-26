require 'rails_helper'

RSpec.describe 'Incident reporting', type: :request do
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

  it 'rejects missing descriptions without allocating a number' do
    expect do
      post admin_incidents_path, params: { incident: { description: ' ' } }, as: :json
    end.not_to change(Incident, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'hides reports from other organizations' do
    incident = Incident.create!(organization: create(:organization), reporter: create(:user), description: 'Other store')
    get admin_incident_path(incident)
    expect(response).to have_http_status(:not_found)
  end
end
