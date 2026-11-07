# frozen_string_literal: true

module Products
  class PromotionEligibility
    def initialize(promotion, **context)
      @promotion = promotion
      @product = context.fetch(:product)
      @quantity = context.fetch(:quantity)
      @subtotal = context.fetch(:subtotal)
      @segment = context[:segment]
      @customer = context[:customer]
    end

    def eligible?
      quota_available? && @promotion.promotion_conditions.all? { |condition| matches?(condition) }
    end

    private

    def quota_available?
      redemptions = @promotion.promotion_redemptions
      return false if @promotion.usage_limit && redemptions.count >= @promotion.usage_limit
      return true unless @promotion.customer_limit
      return false if @customer.blank?

      redemptions.where(customer_reference: @customer).count < @promotion.customer_limit
    end

    def matches?(condition)
      case condition.kind
      when 'product' then condition.product_id == @product.id
      when 'category' then condition.category_id == @product.category_id
      when 'min_quantity' then @quantity >= condition.quantity
      when 'min_subtotal' then @subtotal >= condition.amount
      when 'customer_segment' then @segment.present? && condition.customer_segment == @segment
      else false
      end
    end
  end
end
