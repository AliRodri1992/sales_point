# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::SalesChartComponent, type: :component do
  it 'renders the widget title and subtitle' do
    render_inline(described_class.new)

    expect(page).to have_text('Sales')
    expect(page).to have_text('Behavior over the last 7 days')
  end

  it 'renders the period selector with translated options' do
    render_inline(described_class.new)

    expect(page).to have_css('select[aria-label="Sales period"]')
    expect(page).to have_select('Sales period', selected: 'Last 7 days')
    expect(page).to have_text('Last 30 days')
    expect(page).to have_text('This year')
  end

  it 'renders the seven chart points with translated day labels' do
    render_inline(described_class.new)

    expect(page).to have_css('div.rounded-t-lg', count: 7)
    expect(page).to have_text('Mon')
    expect(page).to have_text('Fri')
  end

  it 'highlights the today point' do
    render_inline(described_class.new)

    expect(page).to have_css('div.bg-nexus-green')
    expect(page).to have_css('span.font-semibold', text: 'Today')
  end

  it 'accepts custom data' do
    data = [
      { label: 'admin.dashboard.widgets.sales.days.today', height: 100, color: 'bg-nexus-green', highlight: true }
    ]

    render_inline(described_class.new(data: data))

    expect(page).to have_css('div.rounded-t-lg', count: 1)
    expect(page).to have_text('Today')
  end
end
