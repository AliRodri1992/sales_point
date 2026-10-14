# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin sidebar navigation icons', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  it 'renders distinct SVG icons with accessible labels for each audited navigation entry' do
    get admin_dashboard_path

    expect(response).to have_http_status(:ok)
    sidebar = Nokogiri::HTML(response.body).at_css('#adminSidebar')
    expect(sidebar).to be_present

    names = %w[
      sales new-sale purchase-orders accounts-payable cash-register inventory
      demo-requests suppliers roles-permissions branches users taxes
    ]
    names.each do |name|
      svg = sidebar.at_css("svg[data-sidebar-icon='#{name}']")
      expect(svg).to be_present, "Missing SVG icon for #{name}"
      expect(svg['aria-hidden']).to eq('true')
      expect(svg['stroke']).to eq('currentColor')
      expect(svg.at_css('path, rect, circle')).to be_present
      expect(svg['class']).to match(/\bsize-[45]\b/)
      expect(svg.parent.at_css('.sidebar-label')).to be_present
    end
  end

  it 'keeps SVG navigation icons when the sidebar is collapsed' do
    user.update!(sidebar_collapsed: true)

    get admin_dashboard_path

    sidebar = Nokogiri::HTML(response.body).at_css('#adminSidebar')
    expect(sidebar['class']).to include('sidebar-collapsed')
    expect(sidebar.at_css("a[href='#{admin_purchase_orders_path}'] svg[data-sidebar-icon='purchase-orders']")).to be_present
    expect(sidebar.at_css("a[href='#{admin_account_payables_path}'] svg[data-sidebar-icon='accounts-payable']")).to be_present
  end
end
