# frozen_string_literal: true

# Synthetic purchasing and banking fixtures for the Delta POS demo tenant.
# Existing user-managed offers, bank details and preferred selections are left untouched.
module SupplierCommercialExamples
  OFFERS_PER_SUPPLIER = 4
  PRESENTATIONS = [
    ['Pieza', 1], ['Paquete de 6', 6], ['Caja de 12', 12]
  ].freeze

  class << self
    def seed_products!
      return if Rails.env.production?

      organization = demo_organization
      products = organization.products.not_deleted.available.order(:code).to_a
      suppliers = organization.suppliers.available.order(:code).to_a
      return if products.empty? || suppliers.empty?

      suppliers.each_with_index do |supplier, index|
        seed_supplier_offers(supplier, index, products)
      end
      seed_additional_presentation(suppliers.first, products.first)
    end

    def seed_supplier_offers(supplier, index, products)
      OFFERS_PER_SUPPLIER.times do |offset|
        presentation = PRESENTATIONS[(index + offset) % PRESENTATIONS.length]
        product = products[(index + offset) % products.length]
        seed_offer(supplier, product, presentation, index: index, offset: offset)
      end
    end

    def seed_bank_accounts!
      return if Rails.env.production?

      demo_organization.suppliers.not_deleted.order(:code).each do |supplier|
        # This includes archived records: an intentionally deleted bank account
        # must not be recreated or replaced with a different account number.
        next if supplier.supplier_bank_accounts.exists?

        number = supplier.code.delete_prefix('SUP-').to_i
        supplier.supplier_bank_accounts.create!(
          organization: supplier.organization,
          holder_name: "PROVEEDOR DEMO #{number} - CUENTA FICTICIA",
          bank_name: 'BANCO DE DEMOSTRACION - NO REAL',
          currency_code: 'MXN',
          account_number: format('9900000000%08d', number),
          clabe: demo_clabe(number),
          primary: true
        )
      end
    end

    private

    def demo_organization
      Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    end

    def seed_offer(supplier, product, presentation, index:, offset:)
      name, units = presentation
      attrs = { organization: supplier.organization, supplier: supplier, product: product, presentation_name: name }
      return if SupplierProduct.exists?(attrs)

      was_unlinked = product.supplier_products.empty?
      SupplierProduct.create!(**attrs, **offer_attributes(supplier, product, units, index, offset))
      return unless was_unlinked && product.preferred_supplier_id.nil?

      Suppliers::PreferredSupplier.call(product: product, supplier: supplier, expected_supplier_id: nil)
    end

    def offer_attributes(supplier, product, units, index, offset)
      price = ((index + 1) * 20) + ((offset + 1) * units * 8)
      {
        currency: supplier.currency,
        units_per_package: units,
        purchase_price: price,
        supplier_sku: "#{supplier.code}-#{product.code}-#{units}",
        supplier_barcode: format('990%010d', (supplier.id * 10_000) + product.id),
        discount_percent: offset.odd? ? 3 : 0,
        freight_amount: offset.even? ? 5 : 0,
        nonrecoverable_tax: 0,
        minimum_quantity: 1,
        lead_time_days: (index % 5) + 1
      }
    end

    def seed_additional_presentation(supplier, product)
      return if SupplierProduct.exists?(supplier:, product:, presentation_name: 'Caja de 24')

      SupplierProduct.create!(
        organization: supplier.organization, supplier:, product:, currency: supplier.currency,
        presentation_name: 'Caja de 24', units_per_package: 24, purchase_price: 440,
        supplier_sku: "#{supplier.code}-#{product.code}-24",
        minimum_quantity: 1, discount_percent: 2, freight_amount: 12,
        nonrecoverable_tax: 0, lead_time_days: 2
      )
    end

    def demo_clabe(number)
      body = "999#{format('%014d', number)}"
      weights = [3, 7, 1]
      sum = body.chars.each_with_index.sum { |digit, index| (digit.to_i * weights[index % 3]) % 10 }
      "#{body}#{(10 - (sum % 10)) % 10}"
    end
  end
end
