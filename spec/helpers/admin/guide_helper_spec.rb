# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::GuideHelper, type: :helper do
  let(:actor) { create(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(actor)
    allow(helper).to receive(:current_organization).and_return(nil)
    allow(helper).to receive(:policy).with(Supplier).and_return(double(index?: false))
    allow(actor).to receive(:admin?).and_return(false)
    allow(actor).to receive(:permission?).and_return(false)
  end

  it 'does not expose privileged guide destinations to users without permission' do
    %w[suppliers branches categories purchase_orders supplier_invoices].each do |topic|
      expect(helper.guide_module_path(topic)).to be_nil
    end
  end

  it 'does not generate a destination for unknown topics' do
    expect(helper.guide_module_path('unregistered-feature')).to be_nil
  end

  it 'exposes the permitted category destination without administrator privileges' do
    allow(actor).to receive(:permission?).with('categories.access').and_return(true)

    expect(helper.guide_module_path('categories')).to eq(helper.admin_categories_path)
  end

  it 'exposes purchasing and finance destinations with their respective permissions' do
    allow(actor).to receive(:permission?).with('purchases.view').and_return(true)
    allow(actor).to receive(:permission?).with('accounts_payable.view').and_return(true)

    expect(helper.guide_module_path('purchase_orders')).to eq(helper.admin_purchase_orders_path)
    expect(helper.guide_module_path('supplier_invoices')).to eq(helper.admin_supplier_invoices_path)
  end

  it 'hides onboarding after the organization has completed initial configuration' do
    allow(actor).to receive(:admin?).and_return(true)
    allow(helper).to receive(:current_organization).and_return(double(onboarding_completed?: true))

    expect(helper.guide_module_path('onboarding')).to be_nil
  end

  it 'shows administrative destinations to administrators before onboarding completes' do
    allow(actor).to receive(:admin?).and_return(true)

    expect(helper.guide_module_path('branches')).to eq(helper.admin_branches_path)
    expect(helper.guide_module_path('onboarding')).to eq(helper.admin_onboarding_path)
  end
end
