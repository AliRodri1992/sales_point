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
      return false unless @promotion.organization_id == @product.organization_id && quota_available?

      @promotion.promotion_conditions.group_by(&:kind).all? do |kind, conditions|
        matches_group?(kind, conditions)
      end
    end

    # Diagnostic only: the pricing service remains the source of truth.
    def rejection_reason
      return :organization unless @promotion.organization_id == @product.organization_id

      redemptions = @promotion.promotion_redemptions
      return :usage_limit if @promotion.usage_limit && redemptions.count >= @promotion.usage_limit
      if @promotion.customer_limit
        return :customer_required if @customer.blank?
        return :customer_limit if redemptions.where(customer_reference: @customer).count >= @promotion.customer_limit
      end
      @promotion.promotion_conditions.group_by(&:kind).each do |kind, conditions|
        return kind.to_sym unless matches_group?(kind, conditions)
      end
      nil
    end

    private

    def matches_group?(kind, conditions)
      case kind
      when 'product', 'excluded_product' then match_targets?(conditions, :product, @product.id)
      when 'category', 'excluded_category' then match_targets?(conditions, :category, @product.category_id)
      else conditions.all? { |condition| matches?(condition) }
      end
    end

    def match_targets?(conditions, association, wanted_id)
      targets = conditions.map { |condition| condition.public_send(association) }
      if conditions.first.kind.start_with?('excluded_')
        targets.all? { |target| usable_target?(target) && target.id != wanted_id }
      else
        targets.any? { |target| usable_target?(target) && target.id == wanted_id }
      end
    end

    def usable_target?(target)
      target&.active? && target.deleted_at.nil? && target.organization_id == @promotion.organization_id
    end

    def quota_available?
      redemptions = @promotion.promotion_redemptions
      return false if @promotion.usage_limit && redemptions.count >= @promotion.usage_limit
      return true unless @promotion.customer_limit
      return false if @customer.blank?

      redemptions.where(customer_reference: @customer).count < @promotion.customer_limit
    end

    def matches?(condition)
      case condition.kind
      when 'min_quantity' then @quantity >= condition.quantity
      when 'min_subtotal' then @subtotal >= condition.amount
      when 'customer_segment' then @segment.present? && condition.customer_segment == @segment
      else false
      end
    end
  end
end
