# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase, supplier and finance breadcrumb branches' do
  class BreadcrumbTestHarness
    include Rails.application.routes.url_helpers
    include BreadcrumbsHelper

    attr_accessor :action, :assigns

    def initialize
      @action = 'index'
      @assigns = {}
    end

    def controller
      Struct.new(:view_assigns).new(assigns)
    end

    def params
      { action: }
    end

    def t(key, **options)
      I18n.t(key, **options)
    end
  end

  let(:view) { BreadcrumbTestHarness.new }
  let(:supplier) { create(:supplier) }

  def check(implementation, action:, assigns: {}, count:)
    view.action = action
    view.assigns = assigns
    items = view.public_send(implementation)
    expect(items.size).to eq(count)
    expect(items.last.fetch(:label)).to be_present
    items
  end

  %i[purchase_request_breadcrumb_items purchase_quotation_breadcrumb_items
     purchase_order_breadcrumb_items purchase_return_breadcrumb_items].each do |method|
    {
      'index' => 1, 'new' => 2, 'create' => 2,
      'edit' => 2, 'update' => 2, 'show' => 2
    }.each do |action, count|
      it "renders #{method} on #{action}" do
        check(method, action:, count:)
      end
    end
  end

  it 'uses persisted document code on purchase breadcrumb show' do
    view.action = 'show'
    view.assigns = { 'order' => double(persisted?: true, code: 'PO-CUSTOM') }
    expect(view.purchase_order_breadcrumb_items.last.fetch(:label)).to eq('PO-CUSTOM')
  end

  it 'uses persisted return ID when no code is provided' do
    view.action = 'show'
    view.assigns = { 'return' => double(persisted?: true, id: 42, respond_to?: false) }
    expect(view.purchase_return_breadcrumb_items.last.fetch(:label)).to be_present
  end

  it 'shows receipt details with linked order and receipt ID' do
    order = double(id: 7, code: 'PO-77', persisted?: true, to_param: '7')
    receipt = double(persisted?: true, purchase_order: order, id: 5)
    items = check(:goods_receipt_breadcrumb_items, action: 'show',
                  assigns: { 'receipt' => receipt }, count: 4)
    expect(items.last.fetch(:label)).to eq('#5')
  end

  {
    'index' => 3, 'new' => 4, 'create' => 3
  }.each do |action, count|
    it "shows purchase receipt breadcrumbs in #{action}" do
      order = double(id: 7, code: 'PO-77', persisted?: true, to_param: '7')
      # A new receipt has a fourth breadcrumb; create redirects to show.
      check(:goods_receipt_breadcrumb_items, action:, assigns: { 'order' => order }, count:)
    end
  end

  it 'shows receipt list without a persisted order' do
    check(:goods_receipt_breadcrumb_items, action: 'index', count: 3)
  end

  %i[supplier_address_breadcrumb_items supplier_contact_breadcrumb_items
     supplier_schedule_breadcrumb_items].each do |method|
    it "uses only the supplier listing when #{method} has no supplier" do
      check(method, action: 'index', count: 1)
    end

    {
      'index' => 3, 'new' => 4, 'create' => 4,
      'edit' => 4, 'update' => 4
    }.each do |action, count|
      it "renders #{method} in #{action}" do
        check(method, action:, assigns: { 'supplier' => supplier }, count:)
      end
    end
  end

  {
    'index' => 3, 'new' => 4, 'create' => 4,
    'edit' => 4, 'update' => 4
  }.each do |action, count|
    it "shows supplier product breadcrumbs in #{action}" do
      check(:supplier_product_breadcrumb_items, action:,
            assigns: { 'supplier' => supplier }, count:)
    end

    it "shows supplier bank breadcrumbs in #{action}" do
      check(:supplier_bank_account_breadcrumb_items, action:,
            assigns: { 'supplier' => supplier }, count:)
    end
  end

  it 'shows supplier product history action label' do
    check(:supplier_product_breadcrumb_items, action: 'history',
          assigns: { 'supplier' => supplier }, count: 4)
  end

  it 'shows product comparison within supplier context' do
    check(:supplier_product_comparison_breadcrumb_items, action: 'show',
          assigns: { 'supplier' => supplier }, count: 4)
  end

  it 'shows comparison without supplier context' do
    check(:supplier_product_comparison_breadcrumb_items, action: 'show', count: 2)
  end

  it 'supports supplier catalog without supplier context' do
    check(:supplier_product_breadcrumb_items, action: 'index', count: 2)
    check(:supplier_bank_account_breadcrumb_items, action: 'index', count: 2)
  end

  %i[supplier_invoice_breadcrumb_items supplier_payment_breadcrumb_items
     supplier_credit_note_breadcrumb_items account_payable_breadcrumb_items].each do |method|
    %w[index new create edit update show].each do |action|
      it "renders #{method} in #{action}" do
        check(method, action:, count: action == 'index' ? 1 : 2)
      end
    end
  end

  it 'renders a supplier name in detail' do
    items = check(:supplier_breadcrumb_items, action: 'show',
                  assigns: { 'supplier' => supplier }, count: 2)
    expect(items.last.fetch(:label)).to eq(supplier.name)
  end

  %w[new create edit update index].each do |action|
    it "renders supplier listing/action path for #{action}" do
      check(:supplier_breadcrumb_items, action:, assigns: { 'supplier' => supplier },
            count: %w[edit update].include?(action) ? 3 : action == 'index' ? 1 : 2)
    end
  end
end
