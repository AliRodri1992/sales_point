# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier general dossier sections', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def general_panel
    Nokogiri::HTML(response.body).at_css('#supplier-dossier-general')
  end

  it 'renders three independent cards alongside the general-information header' do
    get admin_supplier_path(supplier, tab: 'general')

    expect(response).to have_http_status(:ok)
    header = general_panel.at_xpath('./div[@data-supplier-general-header]')
    areas = general_panel.xpath('./div[@data-supplier-general-area]')

    expect(header).to be_present
    expect(header.at_css('dl')).to be_nil
    expect(areas.pluck('data-supplier-general-area')).to eq(
      %w[identification contact_management additional]
    )
    expect(areas.pluck('class')).to all(include('rounded-2xl'))
    expect(areas.pluck('class')).to all(include('bg-white'))
    expect(areas.pluck('class')).to all(include('shadow-sm'))
    expect(areas.map { |area| area.at_css('h3').text.strip }).to eq(
      %w[identification contact_management additional].map do |section|
        I18n.t("admin.supplier_general_layout.#{section}")
      end
    )
    expect(areas.first.text).to include(supplier.name)
    expect(areas[1].text).to include(I18n.t('admin.supplier_dossier.overview.phone'))
    expect(areas.last.text).to include(I18n.t('admin.supplier_dossier.notes'))
  end

  it 'retains the edit entry point in the independent general header' do
    get admin_supplier_path(supplier, tab: 'general')

    expect(general_panel.at_css('[data-supplier-general-header] a')['href'])
      .to eq(edit_admin_supplier_path(supplier, return_to: 'general'))
  end

  it 'omits the edit entry point for users without supplier update permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:update?).and_return(false)

    get admin_supplier_path(supplier, tab: 'general')

    expect(general_panel.at_css('[data-supplier-general-header] a')).to be_nil
    expect(general_panel.css('[data-supplier-general-area]').length).to eq(3)
  end
end
