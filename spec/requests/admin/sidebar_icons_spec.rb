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

  it 'makes future features non-clickable and gives the sidebar a mobile close control' do
    get admin_dashboard_path

    sidebar = Nokogiri::HTML(response.body).at_css('#adminSidebar')
    expect(sidebar.at_css('nav a[href="#"]')).to be_nil
    expect(sidebar.css('nav [aria-disabled="true"]')).not_to be_empty
    close_button = sidebar.at_css('#sidebarCloseButton')
    expect(close_button['aria-label']).to eq(
      I18n.t('admin.shared.sidebar.close_navigation', locale: :en)
    )
    expect(close_button.at_css('svg path')).to be_present
    expect(sidebar.at_css('nav')['aria-label']).to eq(I18n.t('admin.shared.sidebar.navigation', locale: :en))
    expect(sidebar.at_css("a[href='#{admin_suppliers_path}']")['aria-current']).to eq('false')
    expect(sidebar.to_html).not_to include('data-tooltip="Low stock">8')
  end

  it 'highlights supplier dossier subpages under Suppliers with aria-current' do
    supplier = create(:supplier, organization:)

    get admin_supplier_addresses_path(supplier)

    sidebar = Nokogiri::HTML(response.body).at_css('#adminSidebar')
    expect(sidebar.at_css("a[href='#{admin_suppliers_path}']")['aria-current']).to eq('page')
  end

  it 'keeps SVG navigation icons when the sidebar is collapsed' do
    user.update!(sidebar_collapsed: true)

    get admin_dashboard_path

    sidebar = Nokogiri::HTML(response.body).at_css('#adminSidebar')
    expect(sidebar['class']).to include('sidebar-collapsed')
    purchase_orders = sidebar.at_css("a[href='#{admin_purchase_orders_path}']")
    accounts_payable = sidebar.at_css("a[href='#{admin_account_payables_path}']")

    expect(purchase_orders.at_css("svg[data-sidebar-icon='purchase-orders']")).to be_present
    expect(accounts_payable.at_css("svg[data-sidebar-icon='accounts-payable']")).to be_present
  end
end
