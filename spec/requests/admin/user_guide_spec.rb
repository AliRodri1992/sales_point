# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Delta POS user guide', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  it 'shows usage instructions and a link from the user menu' do
    create(:organization_membership, user:, organization:)
    sign_in user
    get admin_guide_path
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#guide-suppliers')).to be_present
    expect(document.text).to include('System user guide')
    expect(document.at_css("a[href='#{admin_guide_path}']")).to be_present
  end

  it 'requires authentication' do
    get admin_guide_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
