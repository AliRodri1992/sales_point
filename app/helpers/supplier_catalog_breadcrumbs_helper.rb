# frozen_string_literal: true

module SupplierCatalogBreadcrumbsHelper
  def supplier_product_breadcrumb_items
    supplier = controller.view_assigns['supplier']
    offer = controller.view_assigns['offer']
    supplier_items = supplier_catalog_items(supplier)
    section = { label: t('admin.procurement.title') }
    section[:path] = admin_supplier_supplier_products_path(supplier) if supplier
    return [*supplier_items, section.except(:path)] if params[:action] == 'index'

    label = case params[:action]
            when 'new', 'create' then t('admin.procurement.add')
            when 'edit', 'update' then t('admin.procurement.edit')
            when 'history' then t('admin.procurement.history')
            else offer&.product&.name || t('admin.procurement.title')
            end
    [*supplier_items, section, { label: }]
  end

  def supplier_product_comparison_breadcrumb_items
    supplier = controller.view_assigns['supplier']
    items = supplier_catalog_items(supplier)
    items << { label: t('admin.procurement.title'), path: admin_supplier_supplier_products_path(supplier) } if supplier
    [*items, { label: t('admin.procurement.compare') }]
  end

  def supplier_bank_account_breadcrumb_items
    supplier = controller.view_assigns['supplier']
    items = supplier_catalog_items(supplier)
    section = { label: t('admin.accounts_payable.bank_accounts') }
    section[:path] = admin_supplier_bank_accounts_path(supplier) if supplier
    return [*items, section.except(:path)] if params[:action] == 'index'

    label = case params[:action]
            when 'new', 'create' then t('admin.accounts_payable.new_bank')
            when 'edit', 'update' then t('admin.accounts_payable.edit_bank')
            else t('admin.accounts_payable.bank_accounts')
            end
    [*items, section, { label: }]
  end

  private

  def supplier_catalog_items(supplier)
    base = { label: t('admin.breadcrumbs.suppliers'), path: admin_suppliers_path }
    return [base] unless supplier

    [base, { label: supplier.name, path: admin_supplier_path(supplier) }]
  end
end
