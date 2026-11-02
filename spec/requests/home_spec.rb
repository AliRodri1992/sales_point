require 'rails_helper'

RSpec.describe 'Homes', type: :request do
  let(:user) { create(:user, :english, username: 'Landing User') }

  describe 'GET /index' do
    it 'returns http success' do
      get '/home/index'
      expect(response).to have_http_status(:success)
    end
  end

  it 'offers sign in and registration to visitors' do
    get root_path

    document = Nokogiri::HTML(response.body)
    expect(document.css("a[href='#{new_user_session_path}']").size).to eq(2)
    expect(document.css("a[href='#{new_user_registration_path}']").size).to eq(6)
    expect(document.css('[data-navbar-target="accountMenu"]')).to be_empty
  end

  it 'replaces every registration action with the dashboard for an authenticated visitor' do
    sign_in user
    get root_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css("a[href='#{new_user_session_path}'], a[href='#{new_user_registration_path}']")).to be_empty
    actions = document.css("a[href='#{admin_dashboard_path}']")
    expect(actions.size).to eq(6)
    expect(actions.map { |action| action.text.strip }.uniq).to eq([I18n.t('landing.buttons.dashboard')])
    expect(document.css('[data-navbar-target="accountMenu"] summary').size).to eq(2)
    expect(document.css("a[href='#{admin_profile_path}']").size).to eq(2)
    logout_selector = "form[action='#{destroy_user_session_path}'] input[name='_method'][value='delete']"
    expect(document.css(logout_selector).size).to eq(2)
    expect(document.at_css('meta[name="turbo-cache-control"]')['content']).to eq('no-cache')
  end

  it 'returns to visitor actions after signing out' do
    sign_in user
    delete destroy_user_session_path
    get root_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css('[data-navbar-target="accountMenu"]')).to be_empty
    expect(document.css("a[href='#{new_user_registration_path}']")).not_to be_empty
    expect(document.css("a[href='#{admin_dashboard_path}']")).to be_empty
  end
end
