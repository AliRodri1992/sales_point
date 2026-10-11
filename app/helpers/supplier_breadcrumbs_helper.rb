# frozen_string_literal: true

module SupplierBreadcrumbsHelper
  def supplier_breadcrumb_items
    base = { label: t('admin.shared.sidebar.suppliers'), path: admin_suppliers_path }
    supplier = controller.view_assigns['supplier']

    case params[:action]
    when 'new', 'create'
      [base, { label: t('admin.suppliers.new.title') }]
    when 'show'
      [base, record_breadcrumb(supplier, t('admin.suppliers.show.title'))]
    when 'edit', 'update'
      name = supplier&.name || t('admin.suppliers.show.title')
      [base,
       editable_record_breadcrumb(supplier, name, method(:admin_supplier_path)),
       { label: t('admin.suppliers.edit.title', name: name) }]
    else
      [base]
    end
  end

  def supplier_address_breadcrumb_items
    supplier = controller.view_assigns['supplier']
    base = { label: t('admin.shared.sidebar.suppliers'), path: admin_suppliers_path }
    return [base] unless supplier

    supplier_item = { label: supplier.name, path: admin_supplier_path(supplier) }
    addresses = { label: t('admin.supplier_details.addresses'), path: admin_supplier_addresses_path(supplier) }

    case params[:action]
    when 'new', 'create'
      [base, supplier_item, addresses, { label: t('admin.supplier_details.add_address') }]
    when 'edit', 'update'
      [base, supplier_item, addresses, { label: t('admin.supplier_details.edit_address') }]
    else
      [base, supplier_item, { label: t('admin.supplier_details.addresses') }]
    end
  end

  def supplier_contact_breadcrumb_items
    supplier = controller.view_assigns['supplier']
    base = { label: t('admin.shared.sidebar.suppliers'), path: admin_suppliers_path }
    return [base] unless supplier

    supplier_item = { label: supplier.name, path: admin_supplier_path(supplier) }
    contacts = { label: t('admin.supplier_details.contacts'), path: admin_supplier_contacts_path(supplier) }

    case params[:action]
    when 'new', 'create'
      [base, supplier_item, contacts, { label: t('admin.supplier_details.add_contact') }]
    when 'edit', 'update'
      [base, supplier_item, contacts, { label: t('admin.supplier_details.edit_contact') }]
    else
      [base, supplier_item, { label: t('admin.supplier_details.contacts') }]
    end
  end

  def supplier_schedule_breadcrumb_items
    supplier = controller.view_assigns['supplier']
    base = { label: t('admin.shared.sidebar.suppliers'), path: admin_suppliers_path }
    return [base] unless supplier

    supplier_item = { label: supplier.name, path: admin_supplier_path(supplier, tab: 'schedules') }
    schedules = { label: t('admin.supplier_dossier.schedules'), path: admin_supplier_schedules_path(supplier) }

    case params[:action]
    when 'new', 'create'
      [base, supplier_item, schedules, { label: t('admin.supplier_details.add') }]
    when 'edit', 'update'
      [base, supplier_item, schedules, { label: t('admin.supplier_details.edit') }]
    else
      [base, supplier_item, { label: t('admin.supplier_dossier.schedules') }]
    end
  end
end
