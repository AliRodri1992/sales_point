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
    order = controller.view_assigns['order']
    receipt = controller.view_assigns['receipt']
    base = { label: t('admin.purchases.orders'), path: admin_purchase_orders_path }
    order_item = { label: order&.code || t('admin.purchases.orders') }
    order_item[:path] = admin_purchase_order_path(order) if order&.persisted?

    receipt_list = { label: t('admin.purchases.receipts') }
    receipt_list[:path] = admin_purchase_order_goods_receipts_path(order) if order&.persisted?
    return [base, order_item, receipt_list.except(:path)] if params[:action] == 'index'
    return [base, order_item, receipt_list, { label: t('admin.purchases.new_receipt') }] if params[:action] == 'new'

    if receipt&.persisted?
      order_item = { label: receipt.purchase_order.code, path: admin_purchase_order_path(receipt.purchase_order) }
      return [base, order_item, { label: t('admin.purchases.receipts') },
              { label: "##{receipt.id}" }]
    end

    [base, order_item, receipt_list]
  end

  private

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
