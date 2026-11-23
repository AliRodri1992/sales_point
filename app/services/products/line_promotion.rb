# frozen_string_literal: true

module Products
  # Select one benefit for one line. Each committed redemption references exactly one campaign.
  class LinePromotion
    def initialize(**context)
      @context = context
    end

    def best(currency:, precision:, at:, list:, selected:)
      offers = Promotion.where(organization_id: @context.fetch(:product).organization_id, currency:)
                        .effective_at(at).preload(:promotion_benefits, promotion_conditions: %i[product category])
      candidates = selected ? preview_offer(offers, selected) : offers.where(status: 'active')
      discounts = candidates.filter_map { |offer| eligible_discount(offer, precision, list) }
      discounts.max_by { |offer, discount| rank(offer, discount) } || [nil, BigDecimal('0')]
    end

    private

    def eligible_discount(offer, precision, list)
      return if offer.price_list_id && offer.price_list_id != list&.id
      return unless PromotionEligibility.new(offer, **@context).eligible?

      discount = discount_for(offer, precision)
      [offer, discount.to_d] if discount.positive?
    end

    def preview_offer(offers, selected)
      offer = offers.where(status: %w[active draft]).find_by(id: selected.id)
      raise ArgumentError, 'Invalid promotion' unless offer

      [offer]
    end

    def discount_for(offer, precision)
      subtotal = @context.fetch(:subtotal)
      best = offer.promotion_benefits.map { |benefit| benefit.discount_for(subtotal, precision:) }.max || 0.to_d
      offer.maximum_discount ? [best, offer.maximum_discount.floor(precision)].min : best
    end

    def rank(offer, discount)
      return [1, offer.priority, discount, -offer.id] if offer.combination_mode == 'exclusive'

      [0, discount, offer.priority, -offer.id]
    end
  end
end
