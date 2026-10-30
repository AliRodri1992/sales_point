# frozen_string_literal: true

RSpec.describe Admin::DashboardController, type: :request do
  let(:user) { create(:user) }
  let(:organization) { create(:organization, :with_settings) }

  before do
    create(:organization_membership, user:, organization:)
    create(:employee, organization:, email: user.email)
    sign_in user
  end

  it 'loads dashboard data for an active organization' do
    create(:branch, organization:)
    create(:dashboard_preference, user:, grid_type: 'kpi', widget_id: 'sales')

    get admin_dashboard_path

    expect(response).to have_http_status(:ok)
  end

  it 'renders compact and closely spaced chat and AI launchers' do
    get admin_dashboard_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    chat = document.at_css('#onlineUsersButton')
    assistant = document.at_css('[data-deltin-assistant-target="launcher"]')

    expect(chat).to be_present
    expect(assistant).to be_present
    expect(chat['class']).to include('size-16', 'right-[94px]', 'bottom-5')
    expect(assistant['class']).to include('size-16', 'right-5', 'bottom-5')
    expect(chat.at_css('svg')).to be_present
    expect(assistant.at_css('img.deltin-avatar')).to be_present
  end

  it 'returns success when saving dashboard preferences' do
    post '/admin/dashboard/preferences', params: {
      widgets: [
        { grid_type: 'kpi', widget_id: 'sales', x: 0, y: 0, w: 4, h: 2 }
      ]
    }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('success' => true)
    expect(user.dashboard_preferences.find_by(widget_id: 'sales')).to have_attributes(
      position_x: 0,
      position_y: 0,
      width: 4,
      height: 2
    )
  end

  it 'returns validation errors for invalid dashboard preferences' do
    post '/admin/dashboard/preferences', params: {
      widgets: [
        { grid_type: 'invalid', widget_id: 'sales', x: 0, y: 0, w: 4, h: 2 }
      ]
    }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['success']).to be(false)
  end
end
