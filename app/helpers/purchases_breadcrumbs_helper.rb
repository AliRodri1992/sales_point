# frozen_string_literal: true

module PurchasesBreadcrumbsHelper
  def purchase_order_breadcrumb_items
    purchase_breadcrumb_items('orders', admin_purchase_orders_path, 'order', 'new_order')
  end

  def purchase_request_breadcrumb_items
    purchase_breadcrumb_items('requests', admin_purchase_requests_path, 'request', 'new_request')
  end

  def purchase_quotation_breadcrumb_items
    purchase_breadcrumb_items('quotations', admin_purchase_quotations_path, 'quotation', 'new_quotation')
  end

  def purchase_return_breadcrumb_items
    purchase_breadcrumb_items('returns', admin_purchase_returns_path, 'return', 'new_return')
  end

  def goods_receipt_breadcrumb_items
    receipt = controller.view_assigns['receipt']
    return goods_receipt_detail_breadcrumbs(receipt) if receipt&.persisted?

    goods_receipt_order_breadcrumbs(controller.view_assigns['order'])
  end

  private

  def goods_receipt_detail_breadcrumbs(receipt)
    order = receipt.purchase_order
    [
      { label: t('admin.purchases.orders'), path: admin_purchase_orders_path },
      { label: order.code, path: admin_purchase_order_path(order) },
      { label: t('admin.purchases.receipts') },
      { label: "##{receipt.id}" }
    ]
  end

  def goods_receipt_order_breadcrumbs(order)
    trail = [
      { label: t('admin.purchases.orders'), path: admin_purchase_orders_path },
      goods_receipt_purchase_order_item(order),
      goods_receipt_list_item(order)
    ]
    return [*trail, { label: t('admin.purchases.new_receipt') }] if params[:action] == 'new'

    trail.last.delete(:path) if params[:action] == 'index'
    trail
  end

  def goods_receipt_purchase_order_item(order)
    item = { label: order&.code || t('admin.purchases.orders') }
    item[:path] = admin_purchase_order_path(order) if order&.persisted?
    item
  end

  def goods_receipt_list_item(order)
    item = { label: t('admin.purchases.receipts') }
    item[:path] = admin_purchase_order_goods_receipts_path(order) if order&.persisted?
    item
  end

  def purchase_breadcrumb_items(section, path, record_name, new_key)
    base = { label: t("admin.purchases.#{section}"), path: }
    return [base.except(:path)] if params[:action] == 'index'

    record = controller.view_assigns[record_name]
    detail = record_breadcrumb_label(record, section)
    label = case params[:action]
            when 'new', 'create' then t("admin.purchases.#{new_key}")
            when 'edit', 'update' then t('admin.purchases.edit')
            else detail
            end

    [base, { label: }]
  end

  def record_breadcrumb_label(record, section)
    return t("admin.purchases.#{section}") unless record&.persisted?

    record.respond_to?(:code) ? record.code : "##{record.id}"
  end
end
