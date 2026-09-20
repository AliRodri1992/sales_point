# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::QuickActionsComponent, type: :component do
  it 'renders the header' do
    render_inline(described_class.new)

    expect(page).to have_text('Quick actions')
    expect(page).to have_text('Quickly access the main features')
  end

  it 'renders the four action cards' do
    render_inline(described_class.new)

    expect(page).to have_css('a.group', count: 4)
  end

  it 'renders translated action labels and descriptions' do
    render_inline(described_class.new)

    expect(page).to have_text('New sale')
    expect(page).to have_text('Open POS')
    expect(page).to have_text('Add product')
    expect(page).to have_text('New customer')
    expect(page).to have_text('Cash close')
    expect(page).to have_text('Check cash register')
  end
end
