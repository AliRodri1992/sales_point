# frozen_string_literal: true

# Sample purchasing documents deliberately remain drafts; no financial postings.
module DemoPurchasingExamples
  REQUEST_COUNT = 24
  QUOTATION_COUNT = 20
  ORDER_COUNT = 20
  INVOICE_COUNT = 20

  module_function

  def seed_purchase_requests!(organization:, admin:)
    branches, products = catalog(organization)
    REQUEST_COUNT.times do |index|
      seed_request!(organization:, admin:, branches:, products:, index:)
    end
  end

  def seed_request!(organization:, admin:, branches:, products:, index:)
    code = demo_code('REQ', index)
    return if organization.purchase_requests.exists?(code:)

    organization.purchase_requests.create!(
      code:, branch: branches[index % branches.size], requested_by: admin,
      status: :draft, needed_on: Date.current + 14.days,
      notes: 'Solicitud de ejemplo; sin autorizar.',
      purchase_request_items_attributes: request_items(products, index)
    )
  end

  def seed_purchase_quotations!(organization:)
    _branches, products = catalog(organization)
    suppliers = active_suppliers(organization)
    currency = Currency.active.find_by!(code: 'MXN')
    QUOTATION_COUNT.times do |index|
      seed_quotation!(organization:, suppliers:, products:, currency:, index:)
    end
  end

  def seed_quotation!(organization:, suppliers:, products:, currency:, index:)
    code = demo_code('QT', index)
    return if organization.purchase_quotations.exists?(code:)

    organization.purchase_quotations.create!(
      code:, supplier: suppliers[index % suppliers.size], currency:,
      status: :draft, valid_until: Date.current + 30.days,
      notes: 'Cotización de demostración sin enviar.',
      purchase_quotation_items_attributes: quote_items(products, index)
    )
  end

  def seed_purchase_orders!(organization:, admin:)
    branches, products = catalog(organization)
    suppliers = active_suppliers(organization)
    currency = Currency.active.find_by!(code: 'MXN')
    sources = [branches, suppliers, products, currency]
    ORDER_COUNT.times do |index|
      seed_order!(organization:, admin:, sources:, index:)
    end
  end

  def seed_order!(organization:, admin:, sources:, index:)
    branches, suppliers, products, currency = sources
    code = demo_code('PO', index)
    return if organization.purchase_orders.exists?(code:)

    organization.purchase_orders.create!(
      code:, branch: branches[index % branches.size], supplier: suppliers[index % suppliers.size],
      requested_by: admin, currency:, status: :draft, expected_on: Date.current + 15.days,
      freight_amount: 0, insurance_amount: 0, exchange_rate: 1,
      notes: 'Orden de demostración sin aprobar.',
      purchase_order_items_attributes: order_items(products, index)
    )
  end

  def seed_supplier_invoices!(organization:, admin:)
    suppliers = active_suppliers(organization)
    currency = Currency.active.find_by!(code: 'MXN')
    INVOICE_COUNT.times do |index|
      seed_invoice!(organization:, admin:, suppliers:, currency:, index:)
    end
  end

  def seed_invoice!(organization:, admin:, suppliers:, currency:, index:)
    folio = demo_code('FACT', index)
    return if organization.supplier_invoices.exists?(source: :manual, folio:)

    amount = 500 + ((index + 1) * 20)
    invoice = organization.supplier_invoices.create!(
      supplier: suppliers[index % suppliers.size], currency:, created_by: admin,
      source: :manual, status: :draft, folio:,
      issued_on: Date.current, received_on: Date.current, due_on: Date.current + 30.days,
      subtotal: amount, tax_amount: 0, total: amount, exchange_rate: 1,
      notes: 'Documento de muestra sin contabilizar ni pagar.'
    )
    invoice.supplier_invoice_lines.create!(
      description: "Artículos de muestra #{index + 1}", quantity: 1,
      unit_price: amount, amount:
    )
  end

  def catalog(organization)
    branches = organization.branches.not_deleted.order(:id).limit(5).to_a
    products = organization.products.not_deleted.order(:id).to_a
    raise 'Se requieren sucursales y dos productos para datos de compras demo' if branches.empty? || products.size < 2

    [branches, products]
  end

  def active_suppliers(organization)
    suppliers = organization.suppliers.available.order(:id).to_a
    raise 'No hay proveedores activos para documentos de compras demo' if suppliers.empty?

    suppliers
  end

  def demo_code(prefix, index)
    format('DEMO-%<prefix>s-%<number>04d', prefix:, number: index + 1)
  end

  def selected_products(products, index)
    [products[index % products.size], products[(index + 1) % products.size]]
  end

  def request_items(products, index)
    selected_products(products, index).map do |product|
      { product_id: product.id, quantity: 3 + ((index + 1) % 9), notes: 'Partida de demostración.' }
    end
  end

  def quote_items(products, index)
    selected_products(products, index).map do |product|
      { product_id: product.id, quantity: 5, units_per_package: 1,
        unit_price: product.cost || 10, discount_percent: 0, lead_time_days: 7 }
    end
  end

  def order_items(products, index)
    selected_products(products, index).map do |product|
      { product_id: product.id, quantity: 4, units_per_package: 1,
        unit_price: product.cost || 10, discount_percent: 0 }
    end
  end
end
