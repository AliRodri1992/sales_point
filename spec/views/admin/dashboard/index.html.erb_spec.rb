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

  it 'omits onboarding when no progress is present' do
    render
    expect(rendered).not_to have_css('#onboarding-card-title')
  end
end
