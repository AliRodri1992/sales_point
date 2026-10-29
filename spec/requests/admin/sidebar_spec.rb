# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin sidebar', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'sidebar navigation accessibility' do
    it 'renders the collapsed navigation with persistent accessible link names' do
      user.update!(sidebar_collapsed: true)
      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="adminSidebar"')
      expect(response.body).to include('sidebar-collapsed')
      expect(response.body).to match(/href="[^"]*"[^>]*aria-label="[^"]+"/)
    end

    it 'does not offer inactive Sales and Inventory flyout groups' do
      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-sidebar-icon="inventory"')
      expect(response.body).not_to include('data-sidebar-icon="sales"')
      expect(response.body).to include(admin_products_path)
    end
  end

  it 'exposes one accessible navigation landmark name' do
    get admin_dashboard_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('#adminSidebar')['aria-labelledby']).to eq('adminSidebarNavigationLabel')
    expect(doc.at_css('#adminSidebarNavigationLabel')).to be_present
    expect(doc.at_css('#adminSidebar')['aria-label']).to be_present
  end

  it 'renders the official Delta POS favicon and sidebar brand' do
    get admin_dashboard_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('#adminSidebar .sidebar-brand-mark')['src']).to include('delta-pos-favicon')
    expect(doc.at_css('link[rel="icon"]')['href']).to include('delta-pos-favicon')
  end

  it 'shows the actual active role in both account menus' do
    role = create(:system_role, :system, name: 'Supervisor', code: 'supervisor')
    create(:user_role, user:, system_role: role)
    get admin_dashboard_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('#sidebarUserMenu').text).to include('Supervisor')
    expect(doc.at_css('#userMenu').text).to include('Supervisor')
  end

  it 'provides the same account actions in both menus without keyboard-trapping unavailable options' do
    get admin_dashboard_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.css('#adminSidebar [aria-disabled="true"][tabindex="0"]')).to be_empty
    expect(doc.css('#sidebarUserMenu a[href]').pluck('href')).to include(admin_guide_path)
    expect(doc.css('#userMenu a[href]').pluck('href')).to include(admin_guide_path)
  end

  it 'uses one normalized icon family for navigation' do
    get admin_dashboard_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('#adminSidebar nav svg[data-sidebar-icon="dashboard"]')).to be_present
    expect(doc.at_css('#adminSidebar nav svg[data-sidebar-icon="catalogs"]')).to be_present
  end

  describe 'topbar accessibility regressions' do
    it 'provides a controlled account and notifications dropdown' do
      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('aria-controls="userMenu"')
      expect(response.body).to include('aria-controls="notificationsMenu"')
    end

    it 'removes the nonfunctional user settings button' do
      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('cog-6-tooth')
      expect(response.body).to include(admin_profile_path)
    end
  end

  it 'provides a stable main-content target for the mobile drawer' do
    get admin_dashboard_path

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('#adminDashboardContent')).to be_present
    expect(doc.at_css('#adminSidebar')).to be_present
    expect(doc.at_css('#sidebarOverlay')).to be_present
  end

  describe 'PATCH /admin/sidebar' do
    it 'collapses the sidebar when the parameter is true' do
      patch admin_sidebar_path, params: { sidebar_collapsed: 'true' }

      expect(response).to have_http_status(:ok)
      expect(user.reload.sidebar_collapsed).to be(true)
    end

    it 'expands the sidebar when the parameter is false' do
      user.update!(sidebar_collapsed: true)

      patch admin_sidebar_path, params: { sidebar_collapsed: 'false' }

      expect(response).to have_http_status(:ok)
      expect(user.reload.sidebar_collapsed).to be(false)
    end

    it 'updates the preference even if another profile attribute is invalid' do
      user.update_column(:theme, nil)

      patch admin_sidebar_path, params: { sidebar_collapsed: 'true' }

      expect(response).to have_http_status(:ok)
      expect(user.reload.sidebar_collapsed).to be(true)
    end

    it 'requires authentication' do
      sign_out user

      patch admin_sidebar_path, params: { sidebar_collapsed: 'true' }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
