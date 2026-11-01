# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'admin/dashboard/index.html.erb', type: :view do
  let(:user) { instance_double(User) }

  before do
    assign(:onboarding_progress, nil)
    assign(:sales_requirements, {})
    assign(:dashboard_preferences, [])
  end

  it 'renders successfully' do
    render
    expect(rendered).to have_css('.dashboard-grid')
  end

  it 'renders the page header' do
    render
    expect(rendered).to have_css('h1')
  end

  it 'renders the onboarding card' do
    render
    expect(rendered).to have_css('[data-controller="onboarding-card"]', minimum: 0)
  end
end
