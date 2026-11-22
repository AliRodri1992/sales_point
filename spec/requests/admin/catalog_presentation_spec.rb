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
end
