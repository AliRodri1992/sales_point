# frozen_string_literal: true

module Admin
  module GuideHelper
    def guide_module_path(topic)
      return unless guide_module_accessible?(topic)

      case topic.to_s
      when 'dashboard' then admin_dashboard_path
      when 'onboarding' then admin_onboarding_path unless current_organization&.onboarding_completed?
      when 'profile' then admin_profile_path
      when 'branches', 'inventory' then admin_branches_path
      when 'organization_contacts' then admin_organization_contacts_path
      when 'users' then admin_users_path
      when 'roles' then system_roles_path
      when 'languages' then admin_languages_path
      when 'categories' then admin_categories_path
      when 'products' then admin_products_path
      when 'clients' then admin_clients_path
      when 'suppliers', 'supplier_contacts', 'supplier_addresses', 'supplier_fiscal',
           'supplier_commercial', 'supplier_products', 'supplier_documents',
           'supplier_calendar', 'supplier_banks', 'supplier_export'
        admin_suppliers_path
      when 'purchase_requests' then admin_purchase_requests_path
      when 'purchase_quotations' then admin_purchase_quotations_path
      when 'purchase_orders', 'goods_receipts' then admin_purchase_orders_path
      when 'purchase_returns' then admin_purchase_returns_path
      when 'supplier_invoices' then admin_supplier_invoices_path
      when 'payables' then admin_account_payables_path
      when 'supplier_payments' then admin_supplier_payments_path
      when 'supplier_credits' then admin_supplier_credit_notes_path
      when 'demo_requests' then admin_demo_requests_path
      end
    end

    private

    def guide_module_accessible?(topic)
      topic = topic.to_s
      if topic.start_with?('supplier_') && !topic.in?(%w[supplier_invoices supplier_payments supplier_credits])
        return policy(Supplier).index?
      end

      return policy(Supplier).index? if topic == 'suppliers'
      return current_user.admin? if topic.in?(%w[onboarding branches inventory organization_contacts users roles demo_requests])
      return current_user.admin? || current_user.permission?('categories.access') if topic == 'categories'
      return current_user.admin? || current_user.permission?('purchases.view') if topic.start_with?('purchase_') || topic == 'goods_receipts'
      return current_user.admin? || current_user.permission?('accounts_payable.view') if topic.in?(%w[payables supplier_invoices supplier_payments supplier_credits])

      true
    end
  end
end
