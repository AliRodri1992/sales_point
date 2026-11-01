# frozen_string_literal: true

module Admin
  module GuideHelper
    GUIDE_DESTINATIONS = {
      'dashboard' => :admin_dashboard_path,
      'onboarding' => :admin_onboarding_path,
      'profile' => :admin_profile_path,
      'branches' => :admin_branches_path,
      'inventory' => :admin_branches_path,
      'organization_contacts' => :admin_organization_contacts_path,
      'users' => :admin_users_path,
      'roles' => :system_roles_path,
      'languages' => :admin_languages_path,
      'categories' => :admin_categories_path,
      'products' => :admin_products_path,
      'clients' => :admin_clients_path,
      'suppliers' => :admin_suppliers_path,
      'supplier_contacts' => :admin_suppliers_path,
      'supplier_addresses' => :admin_suppliers_path,
      'supplier_fiscal' => :admin_suppliers_path,
      'supplier_commercial' => :admin_suppliers_path,
      'supplier_products' => :admin_suppliers_path,
      'supplier_documents' => :admin_suppliers_path,
      'supplier_calendar' => :admin_suppliers_path,
      'supplier_banks' => :admin_suppliers_path,
      'supplier_export' => :admin_suppliers_path,
      'purchase_requests' => :admin_purchase_requests_path,
      'purchase_quotations' => :admin_purchase_quotations_path,
      'purchase_orders' => :admin_purchase_orders_path,
      'goods_receipts' => :admin_purchase_orders_path,
      'purchase_returns' => :admin_purchase_returns_path,
      'supplier_invoices' => :admin_supplier_invoices_path,
      'payables' => :admin_account_payables_path,
      'supplier_payments' => :admin_supplier_payments_path,
      'supplier_credits' => :admin_supplier_credit_notes_path,
      'demo_requests' => :admin_demo_requests_path
    }.freeze

    SUPPLIER_TOPICS = %w[
      suppliers supplier_contacts supplier_addresses supplier_fiscal supplier_commercial
      supplier_products supplier_documents supplier_calendar supplier_banks supplier_export
    ].freeze
    ADMIN_TOPICS = %w[onboarding branches inventory organization_contacts users roles demo_requests].freeze
    PURCHASE_TOPICS = %w[purchase_requests purchase_quotations purchase_orders goods_receipts purchase_returns].freeze
    FINANCIAL_TOPICS = %w[payables supplier_invoices supplier_payments supplier_credits].freeze

    def guide_module_path(topic)
      topic = topic.to_s
      return unless guide_module_accessible?(topic)
      return if topic == 'onboarding' && current_organization&.onboarding_completed?

      path = GUIDE_DESTINATIONS[topic]
      public_send(path) if path
    end

    private

    def guide_module_accessible?(topic)
      return policy(Supplier).index? if SUPPLIER_TOPICS.include?(topic)
      return current_user.admin? if ADMIN_TOPICS.include?(topic)
      return allowed_to_manage_categories? if topic == 'categories'
      return allowed_to_purchase? if PURCHASE_TOPICS.include?(topic)
      return allowed_to_finance? if FINANCIAL_TOPICS.include?(topic)

      true
    end

    def allowed_to_manage_categories?
      current_user.admin? || current_user.permission?('categories.access')
    end

    def allowed_to_purchase?
      current_user.admin? || current_user.permission?('purchases.view')
    end

    def allowed_to_finance?
      current_user.admin? || current_user.permission?('accounts_payable.view')
    end
  end
end
