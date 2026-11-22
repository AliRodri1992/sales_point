# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalog headings and browser titles', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:records) do
    { categories: create(:category, organization:), languages: administrator.language,
      products: create(:product, organization:), units_of_measure: create(:unit_of_measure, organization:) }
  end

  before do
    create(:organization_membership, organization:, user: administrator)
    sign_in administrator
  end

  {
    'es' => ['Catálogos', 'Categorías', 'Idiomas', 'Productos', 'Unidades de medida'],
    'en' => ['Catalogs', 'Categories', 'Languages', 'Products', 'Units of measure'],
    'ko' => ['카탈로그', '카테고리', '언어', '상품', '측정 단위']
  }.each do |locale, labels|
    it "keeps the #{locale} module title on index, new, edit and show with a common heading" do
      language = Language.find_by(code: locale) || create(:language, code: locale, name: locale, flag_iso: locale)
      administrator.update!(language:)

      records.values.each_with_index do |record, index|
        paths = [polymorphic_path([:admin, record.class]), new_polymorphic_path([:admin, record.class]),
                 edit_polymorphic_path([:admin, record]), polymorphic_path([:admin, record])]
        paths.each_with_index do |path, action|
          get path
          expect(response).to have_http_status(:ok)
          document = Nokogiri::HTML(response.body)
          expect(document.at_css('head title').text).to eq("Delta POS | #{labels[index + 1]}")
          next unless action.zero?

          expect(document.at_css('.catalog-module-heading .catalog-eyebrow').text.strip).to eq(labels.first)
          expect(document.at_css('.catalog-module-title').text.strip).to eq(labels[index + 1])
          breadcrumb = document.css('nav[aria-label]').find do |nav|
            nav['aria-label'] == I18n.t('admin.breadcrumbs.label', locale:, raise: true)
          end
          expect(breadcrumb.text).to include(labels[index + 1])
        end
      end
    end
  end

  it 'preserves titles of pages outside these four catalogs' do
    get admin_clients_path
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('head title').text).to eq('Customers')
  end

  it 'shares the category directory structure while retaining each module’s data and actions' do
    records.each do |key, record|
      get polymorphic_path([:admin, record.class])
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('.catalog-list-header .catalog-module-title')).to be_present
      directory = document.at_css('.catalog-list-directory')
      expect(directory).to be_present
      expect(directory.at_css('.catalog-list-directory-heading h2')).to be_present
      expect(directory.at_css('.catalog-list-desktop-table .catalog-list-table')).to be_present
      expect(directory.at_css('.catalog-list-mobile-list .catalog-list-mobile-card')).to be_present
      footer = directory.at_css('footer.catalog-list-pagination')
      expect(footer).to be_present
      expect(footer.at_css('label')['for']).to eq("#{key}_per_page")
      expect(footer.at_css('select')['data-table-page-size-key-value']).to eq(key.to_s)
    end
  end

  it 'keeps collection navigation after a Turbo update replaces the directory' do
    create_list(:category, 6, organization:)
    create_list(:language, 6)
    create_list(:unit_of_measure, 6, organization:)

    records.except(:products).each_value do |record|
      path = polymorphic_path([:admin, record.class])
      patch polymorphic_path([:admin, record], format: :turbo_stream, per_page: 5),
            params: { record.model_name.param_key => { name: 'Updated catalog record' } }
      expect(response).to have_http_status(:ok)
      selectors = '.catalog-list-pagination-links a, .catalog-list-mobile-sort a, .catalog-list-table th a'
      links = Nokogiri::HTML(response.body).css(selectors)
      expect(links).not_to be_empty
      expect(links.map { |link| URI.parse(link['href']).path }.uniq).to eq([path])
    end
  end
end
