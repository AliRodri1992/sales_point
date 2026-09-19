# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::LowStockComponent, type: :component do
  it 'renders the header' do
    render_inline(described_class.new)

    expect(page).to have_text('Inventory')
    expect(page).to have_text('Products that need attention')
  end

  it 'renders the translated alert count' do
    render_inline(described_class.new)

    expect(page).to have_text('8 alerts')
  end

  it 'renders each product with its sku and units' do
    render_inline(described_class.new)

    expect(page).to have_text('Cafe Americano 500g')
    expect(page).to have_text('SKU: CAF-500')
    expect(page).to have_text('2 units')

    expect(page).to have_text('Leche Entera 1L')
    expect(page).to have_text('SKU: LEC-001')
    expect(page).to have_text('5 units')

    expect(page).to have_text('Azucar 1kg')
    expect(page).to have_text('SKU: AZU-001')
    expect(page).to have_text('7 units')
  end

  it 'renders the low quantity in red when stock is critical' do
    render_inline(described_class.new)

    expect(page).to have_css('span.text-red-600', text: '2 units')
    expect(page).to have_css('span.text-amber-600', count: 2)
  end

  it 'renders the view inventory link' do
    render_inline(described_class.new)

    expect(page).to have_link('View inventory')
  end
end
