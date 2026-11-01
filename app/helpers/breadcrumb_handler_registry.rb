# frozen_string_literal: true

module BreadcrumbHandlerRegistry
  HANDLERS = {
    'admin/products' => :product_breadcrumb_items,
    'admin/dashboard' => :dashboard_breadcrumb_items,
    'admin/languages' => :language_breadcrumb_items,
    'admin/categories' => :category_breadcrumb_items,
    'system_roles' => :system_role_breadcrumb_items,
    'admin/profiles' => :profile_breadcrumb_items,
    'admin/branches' => :branch_breadcrumb_items,
    'admin/clients' => :client_breadcrumb_items,
    'admin/suppliers' => :supplier_breadcrumb_items,
    'admin/supplier_addresses' => :supplier_address_breadcrumb_items,
    'admin/supplier_contacts' => :supplier_contact_breadcrumb_items,
    'admin/supplier_schedules' => :supplier_schedule_breadcrumb_items,
    'admin/purchase_orders' => :purchase_order_breadcrumb_items,
    'admin/purchase_requests' => :purchase_request_breadcrumb_items,
    'admin/purchase_quotations' => :purchase_quotation_breadcrumb_items,
    'admin/purchase_returns' => :purchase_return_breadcrumb_items,
    'admin/goods_receipts' => :goods_receipt_breadcrumb_items,
    'admin/supplier_products' => :supplier_product_breadcrumb_items,
    'admin/supplier_product_comparisons' => :supplier_product_comparison_breadcrumb_items,
    'admin/supplier_bank_accounts' => :supplier_bank_account_breadcrumb_items,
    'admin/account_payables' => :account_payable_breadcrumb_items,
    'admin/supplier_invoices' => :supplier_invoice_breadcrumb_items,
    'admin/supplier_payments' => :supplier_payment_breadcrumb_items,
    'admin/supplier_credit_notes' => :supplier_credit_note_breadcrumb_items,
    'admin/users' => :user_breadcrumb_items
  }.freeze
end
