# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogDesignHelper, type: :helper do
  it 'does not repeat field-level validation errors at the top of a form' do
    product = Product.new(name: '', code: '', price: 10)
    product.valid?

    expect(product.errors[:name]).to be_present
    expect(product.errors[:code]).to be_present
    expect(helper.catalog_errors(product)).to be_nil
  end

  it 'keeps errors without a field but omits the summary heading and bullet list' do
    product = Product.new
    product.errors.add(:base, 'No se pudo completar la operación')

    markup = helper.catalog_errors(product).to_s

    expect(markup).to include('No se pudo completar la operación')
    expect(markup).not_to include(I18n.t('admin.catalog_design.fix_errors'))
    expect(markup).not_to include('<ul', '<li')
  end

  it 'omits a stale category selection that no longer exists' do
    category = create(:category, organization: create(:organization))
    choices = helper.catalog_reference_choices(Category.where(id: category.id), -1)
    expect(choices).to eq([[category.name, category.id]])
  end

  it 'uses Mexican pesos without a selected organization' do
    helper.define_singleton_method(:current_organization) { nil }
    expect(helper.product_currency_code).to eq('MXN')
  end

  it 'formats prices in the configured currency of the selected organization' do
    settings = create(:organization_setting, base_currency: create(:currency, code: 'EUR'))
    helper.define_singleton_method(:current_organization) { settings.organization }
    expect(helper.product_money(12)).to include('€', 'EUR')
  end
end
