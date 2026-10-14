# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier catalog breadcrumb decisions' do
  let(:supplier) { create(:supplier) }
  let(:helper_object) do
    Object.new.tap do |instance|
      instance.extend(SupplierCatalogBreadcrumbsHelper)
      instance.extend(Rails.application.routes.url_helpers)
      instance.define_singleton_method(:t) { |key| key }
      instance.define_singleton_method(:controller) { nil }
      instance.define_singleton_method(:params) { nil }
      allow(instance).to receive(:controller).and_return(
        double(view_assigns: { 'supplier' => supplier, 'offer' => nil })
      )
    end
  end

  def action(name)
    allow(helper_object).to receive(:params).and_return(
      ActionController::Parameters.new(action: name)
    )
  end

  {
    'index' => ['admin.procurement.title', false],
    'new' => ['admin.procurement.add', true],
    'create' => ['admin.procurement.add', true],
    'edit' => ['admin.procurement.edit', true],
    'update' => ['admin.procurement.edit', true],
    'history' => ['admin.procurement.history', true],
    'show' => ['admin.procurement.title', true]
  }.each do |name, (label, nested)|
    it "provides a translated product breadcrumb for #{name}" do
      action(name)
      items = helper_object.supplier_product_breadcrumb_items
      expect(items.last.fetch(:label)).to eq(label)
      expect(items.length).to eq(nested ? 4 : 3)
    end
  end

  {
    'index' => ['admin.accounts_payable.bank_accounts', false],
    'new' => ['admin.accounts_payable.new_bank', true],
    'create' => ['admin.accounts_payable.new_bank', true],
    'edit' => ['admin.accounts_payable.edit_bank', true],
    'update' => ['admin.accounts_payable.edit_bank', true],
    'show' => ['admin.accounts_payable.bank_accounts', true]
  }.each do |name, (label, nested)|
    it "provides the translated bank account breadcrumb for #{name}" do
      action(name)
      items = helper_object.supplier_bank_account_breadcrumb_items
      expect(items.last.fetch(:label)).to eq(label)
      expect(items.length).to eq(nested ? 4 : 3)
    end
  end

  it 'renders a comparison navigation chain for an organization supplier' do
    action('show')
    items = helper_object.supplier_product_comparison_breadcrumb_items
    expect(items.last.fetch(:label)).to eq('admin.procurement.compare')
    expect(items.length).to eq(4)
  end

  it 'does not construct supplier paths when the supplier is absent' do
    allow(helper_object).to receive(:controller).and_return(
      double(view_assigns: { 'supplier' => nil, 'offer' => nil })
    )
    action('index')
    expect(helper_object.supplier_product_breadcrumb_items.length).to eq(2)
    expect(helper_object.supplier_bank_account_breadcrumb_items.length).to eq(2)
    expect(helper_object.supplier_product_comparison_breadcrumb_items.length).to eq(2)
  end

  it 'uses an existing offer product title for nonstandard product actions' do
    offer = double(product: double(name: 'Pencil'))
    allow(helper_object).to receive(:controller).and_return(
      double(view_assigns: { 'supplier' => supplier, 'offer' => offer })
    )
    action('preview')
    expect(helper_object.supplier_product_breadcrumb_items.last.fetch(:label)).to eq('Pencil')
  end
end
