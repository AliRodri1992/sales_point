# frozen_string_literal: true

require 'digest'

module Products
  # Called when an external sale is committed, never when a quote is previewed.
  class RedeemPromotion
    class Unavailable < StandardError; end
    class IdempotencyConflict < StandardError; end

    def initialize(product:, idempotency_key:, customer_reference: nil, **options)
      @product = product
      @key = idempotency_key
      @customer = customer_reference
      @options = options
    end

    def call
      ActiveSupport::Notifications.instrument('promotions.redemption') { commit_redemption }
    end

    private

    def commit_redemption
      @product.with_lock do
        lock_idempotency_key
        previous = PromotionRedemption.find_by(organization_id: @product.organization_id, idempotency_key: @key)
        return consistent_previous(previous) if previous

        result = quote
        raise Unavailable, 'No applicable promotion' unless result.promotion

        result.promotion.with_lock { persist_redemption(result.promotion.id) }
      end
    rescue ActiveRecord::RecordNotUnique
      consistent_previous(PromotionRedemption.find_by!(organization_id: @product.organization_id,
                                                       idempotency_key: @key))
    end

    # Products have separate locks, but a caller's operation reference is unique across its tenant.
    def lock_idempotency_key
      identifier = Digest::SHA256.digest("promotion-redemption/#{@product.organization_id}/#{@key}").unpack1('q>')
      sql = PromotionRedemption.sanitize_sql_array(['SELECT pg_advisory_xact_lock(?)', identifier])
      PromotionRedemption.lease_connection.execute(sql)
    end

    def quote
      Quote.new(product: @product, customer_reference: @customer, **@options).call
    end

    def context_snapshot
      { 'variant_id' => @options[:variant]&.id, 'presentation_id' => @options[:presentation]&.id,
        'price_list_id' => @options[:price_list]&.id, 'customer_segment' => @options[:customer_segment] }
    end

    def consistent_previous(previous)
      valid = previous.product_id == @product.id && previous.customer_reference == @customer
      valid &&= previous.quantity == BigDecimal((@options[:quantity] || 1).to_s)
      valid &&= context_snapshot.all? { |key, value| previous.snapshot[key] == value }
      raise IdempotencyConflict, 'Reference already used for a different operation' unless valid

      previous
    end

    def persist_redemption(promotion_id)
      result = quote
      raise Unavailable, 'Promotion quota changed' unless result.promotion&.id == promotion_id

      PromotionRedemption.create!(organization: @product.organization, product: @product,
                                  promotion: result.promotion, quantity: result.quantity, discount: result.discount,
                                  idempotency_key: @key, customer_reference: @customer,
                                  snapshot: redemption_snapshot(result))
    end

    def redemption_snapshot(result)
      context_snapshot.merge(line_snapshot(result), rule_snapshot(result))
    end

    def rule_snapshot(result)
      {
        'promotion_code' => result.promotion.code, 'priority' => result.promotion.priority,
        'combination_mode' => result.promotion.combination_mode,
        'maximum_discount' => result.promotion.maximum_discount,
        'benefits' => benefit_snapshot(result), 'conditions' => condition_snapshot(result)
      }
    end

    def line_snapshot(result)
      item = result.price_list_item
      { 'unit_price' => result.unit_price.to_s('F'), 'quantity' => result.quantity.to_s('F'),
        'base_units' => result.base_units.to_s('F'), 'subtotal' => result.subtotal.to_s('F'),
        'discount' => result.discount.to_s('F'), 'total' => result.total.to_s('F'), 'currency' => result.currency,
        'price_list_item_id' => item&.id, 'resolved_price_list_id' => item&.price_list_id || @options[:price_list]&.id,
        'minimum_quantity' => item&.minimum_quantity }
    end

    def benefit_snapshot(result)
      result.promotion.promotion_benefits.map { |benefit| benefit.slice('kind', 'value') }
    end

    def condition_snapshot(result)
      result.promotion.promotion_conditions.map do |condition|
        condition.slice('kind', 'product_id', 'category_id', 'quantity', 'amount', 'customer_segment')
      end
    end
  end
end
