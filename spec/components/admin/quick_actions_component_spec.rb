# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::QuickActionsComponent, type: :component do
  around { |example| I18n.with_locale(:en, &example) }

  it 'renders the header' do
    render_inline(described_class.new)

    expect(page).to have_text('Quick actions')
    expect(page).to have_text('Common tasks for your daily operation.')
  end

  it 'links available actions to real forms and labels upcoming modules' do
    render_inline(described_class.new)

    expect(page).to have_link('Product', href: '/admin/products/new')
    expect(page).to have_link('Customer', href: '/admin/clients/new')
    expect(page).to have_no_css('a[href="#"]')
    expect(page).to have_text('Coming soon')
  end

  it 'renders translated action labels and descriptions' do
    render_inline(described_class.new)

    expect(page).to have_text('New sale')
    expect(page).to have_text('Add product')
    expect(page).to have_text('New customer')
    expect(page).to have_text('Cash register')
  end
end
