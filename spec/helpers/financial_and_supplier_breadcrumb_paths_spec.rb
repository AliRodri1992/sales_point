# frozen_string_literal: true

require 'rails_helper'

# Isolates breadcrumbs from controller actions while retaining real Rails route helpers.
class BreadcrumbCoverageHarness
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

RSpec.describe 'Purchase, supplier and finance breadcrumb branches' do
  PURCHASE_METHODS = %i[
    purchase_request_breadcrumb_items purchase_quotation_breadcrumb_items
    purchase_order_breadcrumb_items purchase_return_breadcrumb_items
  ].freeze

  SUPPLIER_METHODS = %i[
    supplier_address_breadcrumb_items supplier_contact_breadcrumb_items
    supplier_schedule_breadcrumb_items
  ].freeze

  FINANCE_METHODS = %i[
    supplier_invoice_breadcrumb_items supplier_payment_breadcrumb_items
    supplier_credit_note_breadcrumb_items account_payable_breadcrumb_items
  ].freeze

  ACTIONS = %w[index new create edit update show].freeze
  SUPPLIER_ACTIONS = %w[index new create edit update].freeze

  let(:view) { BreadcrumbCoverageHarness.new }
  let(:supplier) { create(:supplier) }

  def supplier_assignment
    { 'supplier' => supplier }
  end

  def check(method, action:, count:, assigns: {})
    view.action = action
    view.assigns = assigns
    items = view.public_send(method)
    expect(items.size).to eq(count)
    expect(items.last.fetch(:label)).to be_present
    items
  end

  PURCHASE_METHODS.product(ACTIONS).each do |method, action|
    it "renders #{method} in #{action}" do
      check(method, action:, count: action == 'index' ? 1 : 2)
    end
  end

  it 'renders a persisted purchase document code' do
    view.action = 'show'
    view.assigns = { 'order' => double(persisted?: true, code: 'PO-CUSTOM') }
    expect(view.purchase_order_breadcrumb_items.last.fetch(:label)).to eq('PO-CUSTOM')
  end

  it 'renders the receipt detail with purchase order context' do
    order = double(id: 7, code: 'PO-77', persisted?: true, to_param: '7')
    receipt = double(persisted?: true, purchase_order: order, id: 5)
    items = check(:goods_receipt_breadcrumb_items, action: 'show',
                  assigns: { 'receipt' => receipt }, count: 4)
    expect(items.last.fetch(:label)).to eq('#5')
  end

  it 'renders receipt new and index paths' do
    order = double(id: 7, code: 'PO-77', persisted?: true, to_param: '7')
    check(:goods_receipt_breadcrumb_items, action: 'new', assigns: { 'order' => order }, count: 4)
    check(:goods_receipt_breadcrumb_items, action: 'index', assigns: { 'order' => order }, count: 3)
    check(:goods_receipt_breadcrumb_items, action: 'create', assigns: { 'order' => order }, count: 3)
    check(:goods_receipt_breadcrumb_items, action: 'index', count: 3)
  end

  SUPPLIER_METHODS.each do |method|
    it "renders #{method} without supplier" do
      check(method, action: 'index', count: 1)
    end
  end

  SUPPLIER_METHODS.product(SUPPLIER_ACTIONS).each do |method, action|
    it "renders #{method} in #{action}" do
      count = action == 'index' ? 3 : 4
      check(method, action:, count:, assigns: supplier_assignment)
    end
  end

  SUPPLIER_ACTIONS.each do |action|
    it "renders the supplier product breadcrumb in #{action}" do
      check(:supplier_product_breadcrumb_items, action:,
            count: action == 'index' ? 3 : 4, assigns: supplier_assignment)
    end

    it "renders the bank account breadcrumb in #{action}" do
      check(:supplier_bank_account_breadcrumb_items, action:,
            count: action == 'index' ? 3 : 4, assigns: supplier_assignment)
    end
  end

  it 'renders supplier product history and comparison' do
    check(:supplier_product_breadcrumb_items, action: 'history',
          count: 4, assigns: supplier_assignment)
    check(:supplier_product_comparison_breadcrumb_items, action: 'show',
          count: 4, assigns: supplier_assignment)
  end

  it 'renders supplier product and bank breadcrumbs without supplier context' do
    check(:supplier_product_comparison_breadcrumb_items, action: 'show', count: 2)
    check(:supplier_product_breadcrumb_items, action: 'index', count: 2)
    check(:supplier_bank_account_breadcrumb_items, action: 'index', count: 2)
  end

  FINANCE_METHODS.product(ACTIONS).each do |method, action|
    it "renders #{method} in #{action}" do
      check(method, action:, count: action == 'index' ? 1 : 2)
    end
  end

  it 'renders the supplier detail by name' do
    items = check(:supplier_breadcrumb_items, action: 'show',
                  assigns: supplier_assignment, count: 2)
    expect(items.last.fetch(:label)).to eq(supplier.name)
  end

  ACTIONS.each do |action|
    it "renders supplier breadcrumbs in #{action}" do
      count = case action
              when 'edit', 'update' then 3
              when 'index' then 1
              else 2
              end
      check(:supplier_breadcrumb_items, action:, assigns: supplier_assignment, count:)
    end
  end
end
