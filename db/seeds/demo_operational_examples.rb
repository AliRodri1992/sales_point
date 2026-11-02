# frozen_string_literal: true

# Deterministic demo records for the same tenant as administrador@delta.com.
# Records are only created when absent; rerunning seeds never resets manual edits.
module DemoOperationalExamples
  REQUEST_COUNT = 24
  QUOTATION_COUNT = 20
  ORDER_COUNT = 20
  INVOICE_COUNT = 20
  INVENTORY_BRANCH_COUNT = 3

  module_function

  def seed_employees!(organization:)
    emails = ['administrador@delta.com'] + (1..30).map { |number| "user#{number}@delta.com" }
    User.where(email: emails).order(:id).find_each do |user|
      employee = organization.employees.where(deleted_at: nil).find_or_initialize_by(email: user.email)
      if employee.new_record?
        employee.assign_attributes(first_name: user.email == emails.first ? 'Administrador' : 'Usuario',
                                   last_name: user.username.presence || 'Delta', status: :active)
        employee.save!
      end
      user.update!(employee:) unless user.employee_id
    end
  end

  def seed_organization_contacts!(organization:)
    4.times do |index|
      number = index + 1
      email = "contacto-delta-#{number}@example.com"
      next if organization.contacts.where(email:).exists?

      organization.contacts.create!(
        name: "Contacto Delta #{number}",
        email:, position: %w[Administracion Ventas Compras Soporte].fetch(index),
        primary: index.zero? && !organization.contacts.available.where(primary: true).exists?,
        active: true, notes: 'Contacto de demostración.'
      )
    end
  end

  def seed_purchase_requests!(organization:, admin:)
    branches, products = purchasing_catalog(organization)
    REQUEST_COUNT.times do |index|
      number = index + 1
      code = format('DEMO-REQ-%04d', number)
      next if organization.purchase_requests.exists?(code:)

      organization.purchase_requests.create!(
        code:, branch: branches[index % branches.size], requested_by: admin,
        status: :draft, needed_on: Date.current + 14.days,
        notes: 'Solicitud de ejemplo; sin autorizar.',
        purchase_request_items_attributes: two_products(products, index).map do |product|
          { product_id: product.id, quantity: 3 + (number % 9),
            notes: 'Partida de demostración.' }
        end
      )
    end
  end

  def seed_purchase_quotations!(organization:)
    _branches, products = purchasing_catalog(organization)
    suppliers = organization.suppliers.available.order(:id).to_a
    raise 'No hay proveedores activos para cotizaciones demo' if suppliers.empty?

    currency = Currency.active.find_by!(code: 'MXN')
    QUOTATION_COUNT.times do |index|
      number = index + 1
      code = format('DEMO-QT-%04d', number)
      next if organization.purchase_quotations.exists?(code:)

      organization.purchase_quotations.create!(
        code:, supplier: suppliers[index % suppliers.size], currency:,
        status: :draft, valid_until: Date.current + 30.days,
        notes: 'Cotización de demostración sin enviar.',
        purchase_quotation_items_attributes: two_products(products, index).map do |product|
          { product_id: product.id, quantity: 5, units_per_package: 1,
            unit_price: product.cost || 10, discount_percent: 0, lead_time_days: 7 }
        end
      )
    end
  end

  def seed_purchase_orders!(organization:, admin:)
    branches, products = purchasing_catalog(organization)
    suppliers = organization.suppliers.available.order(:id).to_a
    raise 'No hay proveedores activos para órdenes demo' if suppliers.empty?

    currency = Currency.active.find_by!(code: 'MXN')
    ORDER_COUNT.times do |index|
      number = index + 1
      code = format('DEMO-PO-%04d', number)
      next if organization.purchase_orders.exists?(code:)

      organization.purchase_orders.create!(
        code:, branch: branches[index % branches.size], supplier: suppliers[index % suppliers.size],
        requested_by: admin, currency:, status: :draft, expected_on: Date.current + 15.days,
        freight_amount: 0, insurance_amount: 0, exchange_rate: 1,
        notes: 'Orden de demostración sin aprobar.',
        purchase_order_items_attributes: two_products(products, index).map do |product|
          { product_id: product.id, quantity: 4, units_per_package: 1,
            unit_price: product.cost || 10, discount_percent: 0 }
        end
      )
    end
  end

  def seed_supplier_invoices!(organization:, admin:)
    suppliers = organization.suppliers.available.order(:id).to_a
    raise 'No hay proveedores activos para facturas demo' if suppliers.empty?

    currency = Currency.active.find_by!(code: 'MXN')
    INVOICE_COUNT.times do |index|
      number = index + 1
      folio = format('DEMO-FACT-%04d', number)
      next if organization.supplier_invoices.where(source: :manual, folio:).exists?

      invoice = organization.supplier_invoices.create!(
        supplier: suppliers[index % suppliers.size], currency:, created_by: admin,
        source: :manual, status: :draft, folio:,
        issued_on: Date.current, received_on: Date.current, due_on: Date.current + 30.days,
        subtotal: 500 + (number * 20), tax_amount: 0,
        total: 500 + (number * 20), exchange_rate: 1,
        notes: 'Documento de muestra sin contabilizar ni pagar.'
      )
      invoice.supplier_invoice_lines.create!(
        description: "Artículos de muestra #{number}", quantity: 1,
        unit_price: invoice.subtotal, amount: invoice.subtotal
      )
    end
  end

  def seed_payment_integrations!(organization:)
    %w[card qr].each do |provider|
      next if organization.payment_integrations.where(provider:, deleted_at: nil).exists?

      organization.payment_integrations.create!(provider:, status: :pending, configuration: {})
    end
  end

  def seed_inventories!(organization:, admin:)
    branches = organization.branches.not_deleted.order(:id).limit(INVENTORY_BRANCH_COUNT).to_a
    organization.products.not_deleted.order(:id).find_each.with_index do |product, index|
      branches.each_with_index do |branch, branch_index|
        inventory = Inventory.find_or_create_by!(organization:, branch:, product:) do |record|
          record.stock = 12 + ((index + branch_index) % 25)
          record.min_stock = 5
          record.max_stock = 300
        end
        next unless inventory.previously_new_record?

        inventory.inventory_movements.create!(
          organization:, user: admin, kind: 'adjustment', quantity: inventory.stock,
          stock_before: 0, stock_after: inventory.stock,
          reference: "DEMO-INIT-#{branch.id}-#{product.id}"
        )
      end
    end
  end

  def purchasing_catalog(organization)
    branches = organization.branches.not_deleted.order(:id).limit(5).to_a
    products = organization.products.not_deleted.order(:id).to_a
    raise 'Se requieren sucursales y dos productos para datos de compras demo' if branches.empty? || products.size < 2

    [branches, products]
  end

  def two_products(products, index)
    [products[index % products.size], products[(index + 1) % products.size]]
  end
end
