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
end
