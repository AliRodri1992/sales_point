# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'admin/dashboard/index.html.erb', type: :view do
  let(:product_policy) { instance_double(ProductPolicy, create?: true) }
  let(:client_policy) { instance_double(ClientPolicy, create?: true) }

  before do
    view.extend(Pundit::Authorization)
    allow(view).to receive(:policy).with(Product).and_return(product_policy)
    allow(view).to receive(:policy).with(Client).and_return(client_policy)
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

  it 'shows the product creation action when allowed' do
    render
    expect(rendered).to have_link(href: new_admin_product_path)
  end

  it 'hides the product creation action when permission is denied' do
    allow(product_policy).to receive(:create?).and_return(false)
    render
    expect(rendered).not_to have_link(href: new_admin_product_path)
  end

  it 'hides customer creation independently of product creation' do
    allow(client_policy).to receive(:create?).and_return(false)
    render
    expect(rendered).not_to have_link(href: new_admin_client_path)
    expect(rendered).to have_link(href: new_admin_product_path)
  end
end
