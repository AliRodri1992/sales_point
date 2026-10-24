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
      seed_product_catalog(organization)
    end

    def seed_product_catalog(organization)
      products = demo_products(organization)
      suppliers = demo_suppliers(organization)
      return if products.empty? || suppliers.empty?

      seed_supplier_offers(suppliers, products)
      seed_additional_presentation(suppliers.first, products.first)
    end

    def seed_bank_accounts!
      return if Rails.env.production?

      demo_suppliers(demo_organization).each do |supplier|
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

    def demo_products(organization)
      codes = (1..15).map { |number| format('PROD%04d', number) }
      organization.products.not_deleted.where(code: codes).order(:code).to_a
    end

    def demo_suppliers(organization)
      codes = (1..SupplierExamples::COUNT).map { |number| format('SUP-%04d', number) }
      organization.suppliers.not_deleted.where(code: codes).order(:code).to_a
    end

    def seed_supplier_offers(suppliers, products)
      suppliers.each_with_index do |supplier, supplier_index|
        next unless supplier.active?

        OFFERS_PER_SUPPLIER.times do |offset|
          product = products[(supplier_index + offset) % products.size]
          presentation, units = PRESENTATIONS[(supplier_index + offset) % PRESENTATIONS.size]
          seed_offer(supplier, product, presentation, units, supplier_index:, offset:)
        end
      end
    end

    def seed_offer(supplier, product, presentation, units, position)
      attrs = { organization: supplier.organization, supplier:, product:, presentation_name: presentation }
      supplier_sku = "#{supplier.code}-#{product.code}-#{units}"
      return if SupplierProduct.exists?(attrs) || SupplierProduct.exists?(supplier:, product:, supplier_sku:)

      was_unlinked = product.supplier_products.empty?
      offer = SupplierProduct.create!(attrs.merge(offer_values(supplier, product, units, position)))
      assign_first_preference(product, supplier) if was_unlinked && offer.active? && supplier.active?
    end

    def offer_values(supplier, product, units, position)
      index = position.fetch(:supplier_index)
      offset = position.fetch(:offset)
      {
        currency: supplier.currency, units_per_package: units,
        active: supplier.active? && product.active?,
        purchase_price: ((index + 1) * 20) + ((offset + 1) * units * 8),
        supplier_sku: "#{supplier.code}-#{product.code}-#{units}",
        supplier_barcode: demo_barcode(supplier, product),
        discount_percent: offset.odd? ? 3 : 0,
        freight_amount: offset.even? ? 5 : 0,
        nonrecoverable_tax: 0,
        minimum_quantity: 1,
        lead_time_days: (index % 5) + 1
      }
    end

    def assign_first_preference(product, supplier)
      # An explicitly cleared preference must remain clear after re-seeding.
      return unless product.preferred_supplier_id.nil?

      Suppliers::PreferredSupplier.call(product:, supplier:, expected_supplier_id: nil)
    end

    def seed_additional_presentation(supplier, product)
      return unless supplier.active?
      return if SupplierProduct.exists?(supplier:, product:, presentation_name: 'Caja de 24')
      return if SupplierProduct.exists?(supplier:, product:, supplier_sku: "#{supplier.code}-#{product.code}-24")

      SupplierProduct.create!(
        organization: supplier.organization, supplier:, product:, currency: supplier.currency,
        presentation_name: 'Caja de 24', units_per_package: 24, purchase_price: 440,
        supplier_sku: "#{supplier.code}-#{product.code}-24",
        minimum_quantity: 1, discount_percent: 2, freight_amount: 12,
        nonrecoverable_tax: 0, lead_time_days: 2
      )
    end

    def demo_barcode(supplier, product)
      format('990%010d', (supplier.id * 10_000) + product.id)
    end

    def demo_clabe(number)
      body = "999#{format('%014d', number)}"
      weights = [3, 7, 1]
      sum = body.chars.each_with_index.sum { |digit, index| (digit.to_i * weights[index % 3]) % 10 }
      "#{body}#{(10 - (sum % 10)) % 10}"
    end
  end
end
