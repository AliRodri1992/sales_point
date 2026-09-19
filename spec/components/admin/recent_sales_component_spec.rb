# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::RecentSalesComponent, type: :component do
  it 'renders the header and view all link' do
    render_inline(described_class.new)

    expect(page).to have_text('Recent sales')
    expect(page).to have_text('Latest registered transactions')
    expect(page).to have_link('View all')
  end

  it 'renders the translated column headers' do
    render_inline(described_class.new)

    expect(page).to have_text('Folio')
    expect(page).to have_text('Customer')
    expect(page).to have_text('Method')
    expect(page).to have_text('Total')
    expect(page).to have_text('Status')
  end

  it 'renders a row for each sale' do
    render_inline(described_class.new)

    expect(page).to have_css('tbody tr', count: 4)
  end

  it 'renders the sale data' do
    render_inline(described_class.new)

    expect(page).to have_text('#NV-0186')
    expect(page).to have_text('Juan Perez')
    expect(page).to have_text('$1,250.00')
    expect(page).to have_text('$2,150.00')
  end

  it 'renders translated payment methods' do
    render_inline(described_class.new)

    expect(page).to have_text('Card')
    expect(page).to have_text('Cash', count: 2)
    expect(page).to have_text('Transfer')
  end

  it 'renders translated statuses' do
    render_inline(described_class.new)

    expect(page).to have_text('Completed', count: 3)
    expect(page).to have_text('Pending')
  end
end
