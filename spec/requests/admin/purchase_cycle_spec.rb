# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchasing document and receiving lifecycle', type: :request do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def order_attributes
    {
      branch_id: branch.id, supplier_id: supplier.id, currency_id: supplier.currency.id,
      purchase_order_items_attributes: {
        '0' => { product_id: product.id, quantity: 4, units_per_package: 1, unit_price: 12,
                 nonrecoverable_tax: 0, discount_percent: 0 }
      }
    }
  end

  def submitted_order
    PurchaseOrder.create!(
      organization:, branch:, supplier:, currency: supplier.currency, requested_by: user,
      status: :ordered
    ).tap do |order|
      order.purchase_order_items.create!(
        product:, quantity: 4, units_per_package: 1, unit_price: 12
      )
    end
  end

  it 'prefills a quotation from an approved request' do
    request_record = PurchaseRequest.create!(organization:, branch:, requested_by: user, status: :approved)
    request_record.purchase_request_items.create!(product:, quantity: 9)

    get new_admin_purchase_quotation_path(purchase_request_id: request_record.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(request_record.code)
    expect(response.body).to include('9')
  end

  it 'persists quotation lines submitted by the form' do
    post admin_purchase_quotations_path, params: {
      purchase_quotation: {
        supplier_id: supplier.id, currency_id: supplier.currency.id,
        purchase_quotation_items_attributes: {
          '0' => { product_id: product.id, quantity: 3,
                   units_per_package: 1, unit_price: 10, lead_time_days: 2 }
        }
      }
    }

    quotation = organization.purchase_quotations.order(:id).last
    expect(response).to redirect_to(admin_purchase_quotation_path(quotation))
    expect(quotation.purchase_quotation_items.first).to have_attributes(
      product_id: product.id, quantity: 3, unit_price: 10
    )
  end

  it 'persists and snapshots purchase order lines' do
    post admin_purchase_orders_path, params: { purchase_order: order_attributes }

    order = organization.purchase_orders.order(:id).last
    expect(response).to redirect_to(admin_purchase_order_path(order))
    expect(order.purchase_order_items.first).to have_attributes(
      product_id: product.id, quantity: 4, unit_price: 12
    )
    expect(order.total).to eq(48)
  end

  it 'prefills a draft order from an approved quotation while keeping its negotiated prices' do
    quotation = PurchaseQuotation.create!(
      organization:, supplier:, currency: supplier.currency, status: :accepted, valid_until: Date.tomorrow
    )
    quotation.purchase_quotation_items.create!(
      product:, quantity: 6, units_per_package: 3, unit_price: 42, discount_percent: 8
    )

    get new_admin_purchase_order_path(quotation_id: quotation.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('42')
    expect(response.body).to include(quotation.code)
  end

  it 'rejects purchase orders referencing a draft quotation' do
    quotation = PurchaseQuotation.create!(organization:, supplier:, currency: supplier.currency)
    post admin_purchase_orders_path, params: {
      purchase_order: order_attributes.merge(purchase_quotation_id: quotation.id)
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(organization.purchase_orders.count).to eq(0)
  end

  it 'rejects products from another organization in the purchase order' do
    foreign = create(:product, organization: create(:organization))
    attributes = order_attributes
    attributes[:purchase_order_items_attributes]['0'][:product_id] = foreign.id

    post admin_purchase_orders_path, params: { purchase_order: attributes }

    expect(response).to have_http_status(:unprocessable_content)
    expect(organization.purchase_orders.count).to eq(0)
  end

  it 'receives an order through the controller and updates its branch inventory' do
    order = submitted_order
    post admin_purchase_order_goods_receipts_path(order), params: {
      idempotency_key: 'request-receipt-1',
      entries: { '0' => {
        purchase_order_item_id: order.purchase_order_items.first.id,
        delivered_quantity: 2, accepted_quantity: 2, damaged_quantity: 0
      } }
    }

    receipt = order.goods_receipts.last
    expect(response).to redirect_to(admin_goods_receipt_path(receipt))
    expect(order.reload).to be_partially_received
    expect(Inventory.find_by!(branch:, product:).stock).to eq(2)
  end

  it 'allows skipping an unreceived order line without rejecting the partial delivery' do
    order = submitted_order
    second_product = create(:product, organization:)
    second_line = order.purchase_order_items.create!(
      product: second_product, quantity: 3, units_per_package: 1, unit_price: 5
    )
    post admin_purchase_order_goods_receipts_path(order), params: {
      idempotency_key: 'partial-skip-1',
      entries: {
        '0' => { purchase_order_item_id: order.purchase_order_items.first.id,
                 delivered_quantity: 2, accepted_quantity: 2, damaged_quantity: 0 },
        '1' => { purchase_order_item_id: second_line.id,
                 delivered_quantity: 0, accepted_quantity: 0, damaged_quantity: 0 }
      }
    }

    expect(response).to redirect_to(admin_goods_receipt_path(order.goods_receipts.last))
    expect(order.goods_receipts.last.goods_receipt_items.count).to eq(1)
    expect(Inventory.where(product: second_product).count).to eq(0)
  end

  it 'persists return lines and processes the supplier return' do
    order = submitted_order
    receipt = Purchases::Receive.call(
      order:, user:, idempotency_key: 'request-receipt-2',
      entries: [{ purchase_order_item_id: order.purchase_order_items.first.id,
                  delivered_quantity: 3, accepted_quantity: 3, damaged_quantity: 0 }]
    )
    line = receipt.goods_receipt_items.first

    post admin_goods_receipt_purchase_returns_path(receipt), params: {
      purchase_return: {
        reason: 'damaged',
        purchase_return_items_attributes: { '0' => {
          goods_receipt_item_id: line.id, quantity: 1
        } }
      }
    }

    purchase_return = organization.purchase_returns.order(:id).last
    expect(response).to redirect_to(admin_purchase_return_path(purchase_return))
    expect(purchase_return.purchase_return_items.first.quantity).to eq(1)

    post process_return_admin_purchase_return_path(purchase_return)

    expect(response).to redirect_to(admin_purchase_return_path(purchase_return))
    expect(purchase_return.reload).to be_processed
    expect(Inventory.find_by!(branch:, product:).stock).to eq(2)
  end
end
