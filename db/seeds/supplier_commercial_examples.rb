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

      suppliers.each_with_index do |supplier, supplier_index|
        OFFERS_PER_SUPPLIER.times do |offset|
          product = products[(supplier_index + offset) % products.length]
          name, units = PRESENTATIONS[(supplier_index + offset) % PRESENTATIONS.length]
          seed_offer(supplier, product, name, units, supplier_index, offset)
        end
      end
      seed_additional_presentation(suppliers.first, products.first)
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

    def seed_offer(supplier, product, name, units, supplier_index, offset)
      attrs = { organization: supplier.organization, supplier:, product:, presentation_name: name }
      # A soft-deleted seed example should remain archived on later runs.
      return if SupplierProduct.exists?(attrs)

      was_unlinked = product.supplier_products.empty?
      price = (supplier_index + 1) * 20 + (offset + 1) * units * 8
      SupplierProduct.create!(
        **attrs, currency: supplier.currency, units_per_package: units, purchase_price: price,
        supplier_sku: "#{supplier.code}-#{product.code}-#{units}",
        supplier_barcode: format('990%010d', (supplier.id * 10_000) + product.id),
        discount_percent: offset.odd? ? 3 : 0,
        freight_amount: offset.even? ? 5 : 0,
        nonrecoverable_tax: 0,
        minimum_quantity: 1,
        lead_time_days: (supplier_index % 5) + 1
      )
      # Assign a demo preference only when linking a product for the first time.
      # Clearing that preference manually will not cause it to return on a re-seed.
      return unless was_unlinked && product.preferred_supplier_id.nil?

      Suppliers::PreferredSupplier.call(product:, supplier:, expected_supplier_id: nil)
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
