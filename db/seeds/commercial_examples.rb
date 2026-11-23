# frozen_string_literal: true

module CommercialExamples
  LISTS = [
    ['Mostrador general', 'active', nil],
    ['Mayoreo por volumen', 'active', 'Mayoreo'],
    ['Clientes frecuentes', 'active', 'Frecuente'],
    ['Distribuidores regionales', 'draft', 'Distribuidor'],
    ['Convenio empresarial', 'draft', 'Empresarial'],
    ['Precios de temporada', 'scheduled', nil],
    ['Feria de fin de año', 'scheduled', nil],
    ['Convenio suspendido', 'paused', 'Empresarial'],
    ['Venta especial anterior', 'expired', nil],
    ['Mayoreo anterior', 'expired', 'Mayoreo'],
    ['Catálogo histórico', 'archived', nil],
    ['Precios institucionales', 'draft', 'Institucional']
  ].freeze

  CAMPAIGNS = [
    ['Ahorro de bienvenida', 'active', 'percentage', 10],
    ['Descuento por volumen', 'active', 'percentage', 15],
    ['Ahorro directo en mostrador', 'active', 'fixed_amount', 25],
    ['Beneficio para mayoristas', 'draft', 'percentage', 12],
    ['Especial de temporada', 'scheduled', 'percentage', 20],
    ['Semana de ahorro', 'scheduled', 'fixed_amount', 40],
    ['Premio a clientes frecuentes', 'draft', 'percentage', 8],
    ['Oferta suspendida', 'paused', 'fixed_amount', 15],
    ['Campaña de aniversario anterior', 'expired', 'percentage', 18],
    ['Descuento de feria anterior', 'expired', 'fixed_amount', 30],
    ['Promoción histórica', 'archived', 'percentage', 5],
    ['Compra mínima especial', 'draft', 'fixed_amount', 50]
  ].freeze

  class << self
    def seed_price_lists!(organization:)
      products = demo_products(organization)
      return if products.empty?

      LISTS.each_with_index do |(name, status, segment), index|
        code = format('LP-DEMO-%04d', index + 1)
        next if organization.price_lists.with_deleted.exists?(code:)

        organization.price_lists.create!(code:, name: "Demo · #{name}", currency: 'MXN', customer_segment: segment,
                                         priority: index + 1, **lifecycle_attributes(status),
                                         price_list_items_attributes: price_rows(products, index))
      end
    end

    def seed_promotions!(organization:)
      products = demo_products(organization)
      return if products.empty?

      CAMPAIGNS.each_with_index do |(name, status, kind, value), index|
        code = format('PRO-DEMO-%04d', index + 1)
        next if organization.promotions.with_deleted.exists?(code:)

        organization.promotions.create!(code:, name: "Demo · #{name}", currency: 'MXN', priority: index + 1,
                                         **lifecycle_attributes(status), **campaign_limits(index),
                                         promotion_conditions_attributes: conditions(products, index),
                                         promotion_benefits_attributes: [{ kind:, value: }])
      end
    end

    private

    def demo_products(organization)
      codes = (1..30).map { |number| format('PROD%04d', number) }
      organization.products.not_deleted.available.where(code: codes).includes(:category).order(:code).to_a
    end

    def lifecycle_attributes(status)
      case status
      when 'scheduled' then { status: 'active', starts_at: 30.days.from_now, ends_at: 60.days.from_now }
      when 'expired' then { status: 'active', starts_at: 60.days.ago, ends_at: 30.days.ago }
      else { status: }
      end
    end

    def price_rows(products, index)
      product = products[index % products.size]
      other = products[(index + 1) % products.size]
      [{ product:, minimum_quantity: 0, price: demo_price(product, 95) },
       { product:, minimum_quantity: 10, price: demo_price(product, 85) },
       { product: other, minimum_quantity: 5, price: demo_price(other, 90) }]
    end

    def demo_price(product, percent)
      [(product.price * percent / 100).round(2), product.cost || 0].max
    end

    def campaign_limits(index)
      { usage_limit: 100 + index * 25, customer_limit: (index % 3) + 1,
        maximum_discount: 100 + index * 20, combination_mode: index.even? ? 'best_price' : 'exclusive' }
    end

    def conditions(products, index)
      product = products[index % products.size]
      rules = [{ kind: 'product', product: }]
      category = product.category
      rules << { kind: 'category', category: } if index.even? && active_category?(category)
      rules << { kind: 'min_quantity', quantity: 3 } if index.odd?
      rules << { kind: 'min_subtotal', amount: 300 } if (index % 3).zero?
      rules << { kind: 'customer_segment', customer_segment: 'Mayoreo' } if index == 3
      rules << { kind: 'customer_segment', customer_segment: 'Frecuente' } if index == 6
      rules
    end

    def active_category?(category)
      category&.active? && category.deleted_at.nil?
    end
  end
end
