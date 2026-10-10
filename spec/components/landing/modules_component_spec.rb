# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Landing::ModulesComponent, type: :component do
  it 'renders the section title and subtitle' do
    render_inline(described_class.new(title: 'Built for retail', subtitle: 'Manage your store', modules: []))

    expect(page).to have_text('Built for retail')
    expect(page).to have_text('Manage your store')
  end

  it 'renders each feature module' do
    feature = Struct.new(:icon, :title, :description, :color).new(
      :bolt,
      'Fast checkout',
      'Serve customers quickly',
      :emerald
    )

    render_inline(described_class.new(title: 'Modules', subtitle: 'Features', modules: [feature]))

    expect(page).to have_text('Fast checkout')
    expect(page).to have_text('Serve customers quickly')
  end
end
