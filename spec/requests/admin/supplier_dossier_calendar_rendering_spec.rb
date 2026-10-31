# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier dossier calendar template rendering', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  %w[month week day].each do |view|
    it "renders the #{view} calendar without an ERB syntax error" do
      get admin_supplier_path(supplier, tab: 'schedules', calendar_view: view)

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css('section[data-section="schedules"]')).to be_present
    end
  end
end
