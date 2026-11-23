# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial and configuration browser tab titles', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user: administrator)
    create(:user_role, user: administrator,
                       system_role: create(:system_role, :system, code: 'administrator'))
    sign_in administrator
  end

  it 'uses Delta POS before each Commercial and Configuration module name' do
    destinations = {
      admin_price_lists_path => 'admin.catalog_design.price_lists',
      admin_promotions_path => 'admin.catalog_design.promotions',
      admin_general_settings_path => 'admin.general_settings.title',
      system_roles_path => 'admin.system_roles.index.title',
      admin_branches_path => 'admin.branches.index.title',
      admin_users_path => 'admin.users.index.title',
      admin_email_templates_path => 'admin.email_templates.title'
    }

    destinations.each do |path, title_key|
      get path

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).at_css('head title').text).to eq(
        "Delta POS | #{I18n.t(title_key, locale: :en)}"
      )
    end
  end

  it 'retains the module title on new and detail screens rather than using an unbranded page title' do
    get new_admin_promotion_path
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('head title').text).to eq('Delta POS | Promotions')

    get new_system_role_path
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('head title').text).to eq('Delta POS | Roles & Permissions')
  end

  it 'preserves the existing branded Catalogs tab format' do
    get admin_products_path

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('head title').text).to eq('Delta POS | Products')
  end
end
