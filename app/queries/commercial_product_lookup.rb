# frozen_string_literal: true

class CommercialProductLookup
  LIMIT = 20

  def initialize(organization:, term:, currency:, include_cost:)
    @organization = organization
    @term = "%#{Product.sanitize_sql_like(term.to_s.strip.first(100))}%"
    @currency = currency
    @include_cost = include_cost
  end

  def call
    products = matches.order(:name, :id).limit(LIMIT).preload(:product_variants, :product_presentations)
    products.map do |product|
      row = product.slice(:id, :name, :code, :sku, :price).merge(currency: @currency)
      row[:cost] = product.cost if @include_cost
      row[:variants] = options(product.product_variants, %i[id name])
      row[:presentations] = options(product.product_presentations, %i[id name units])
      row
    end
  end

  private

  def matches
    scope = @organization.products.available
    codes = ProductBarcode.where(organization: @organization).where('value ILIKE ?', @term)
    variants = ProductVariant.active.where(organization: @organization).where('sku ILIKE ?', @term)
    scope.where('name ILIKE :q OR code ILIKE :q OR sku ILIKE :q OR barcode ILIKE :q', q: @term)
         .or(scope.where(id: codes.select(:product_id))).or(scope.where(id: variants.select(:product_id)))
  end

  def options(records, fields)
    records.filter_map do |row|
      row.slice(*fields) if row.organization_id == @organization.id && row.active?
    end
  end
end
