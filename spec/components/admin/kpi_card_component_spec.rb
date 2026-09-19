# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::KpiCardComponent, type: :component do
  it 'renders the title and value' do
    render_inline(described_class.new(title: "Today's sales", value: '$48,250.00'))

    expect(page).to have_text("Today's sales")
    expect(page).to have_text('$48,250.00')
  end

  it 'renders the change badge when provided' do
    render_inline(described_class.new(title: "Today's sales", value: '$48,250.00', change: '+12.5%'))

    expect(page).to have_text('+12.5%')
  end

  it 'renders the status when provided' do
    render_inline(described_class.new(title: 'Current cash', value: '$32,840.00', status: 'Open session'))

    expect(page).to have_text('Open session')
  end

  it 'renders the icon when provided' do
    render_inline(described_class.new(title: "Today's sales", value: '$48,250.00', icon_name: 'banknotes'))

    expect(page).to have_css('svg')
  end

  it 'does not render change, status or icon when omitted' do
    render_inline(described_class.new(title: "Today's sales", value: '$48,250.00'))

    expect(page).to have_no_text('+12.5%')
    expect(page).to have_no_css('span')
    expect(page).to have_no_css('svg')
  end
end
