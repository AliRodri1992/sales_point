# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'home/index.html.erb', type: :view do
  before do
    assign(:features, [])
    assign(:testimonials, [])
    assign(:plans, [])
    assign(:questions, [])
  end

  it 'renders successfully' do
    render
    expect(rendered).to have_css('main')
  end

  it 'renders the hero section' do
    render
    expect(rendered).to have_css('.overflow-x-hidden')
  end

  it 'renders the landing navbar' do
    render
    expect(rendered).to have_css('[class*="Landing::NavbarComponent"]', minimum: 0)
  end

  it 'renders the pricing section' do
    render
    expect(rendered).to have_css('#precios')
  end
end
