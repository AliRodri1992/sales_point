# frozen_string_literal: true

class CommercialPreview
  def initialize(record:, organization:, inputs:)
    @record = record
    @organization = organization
    @inputs = inputs
  end

  def call
    product = @organization.products.available.find(@inputs.fetch(:product_id, nil))
    options = line_options(product).merge(selected_catalog)
    quote = Products::Quote.new(product:, **options).preview
    output = quote.to_h.slice(:unit_price, :subtotal, :discount, :total, :quantity, :currency)
                  .merge(promotion: quote.promotion&.name, price_list: quote.price_list_item&.price_list&.name)
    if @record.is_a?(Promotion) && quote.promotion.nil?
      eligibility = Products::PromotionEligibility.new(@record, product:, quantity: quote.base_units,
                                                      subtotal: quote.subtotal, segment: @inputs[:customer_segment],
                                                      customer: @inputs[:customer_reference])
      output[:explanation] = I18n.t("admin.commercial_preview.reasons.#{eligibility.rejection_reason || :no_discount}")
    end
    output
  end

  private

  def selected_catalog
    return { price_list: @record } if @record.is_a?(PriceList)

    { promotion: @record, price_list: @record.price_list }
  end

  def line_options(product)
    customer = @inputs[:customer_reference]
    raise ArgumentError if customer.to_s.length > 100 || @inputs[:customer_segment].to_s.length > 100

    { quantity: @inputs.fetch(:quantity, 1), customer_reference: customer.presence,
      customer_segment: @inputs[:customer_segment], at: preview_time,
      variant: find_option(product.product_variants, :variant_id),
      presentation: find_option(product.product_presentations, :presentation_id) }
  end

  def find_option(scope, field)
    scope.active.where(organization: @organization).find(@inputs[field]) if @inputs[field].present?
  end

  def preview_time
    @inputs[:at].present? ? Time.zone.iso8601(@inputs[:at].to_s) : Time.current
  end
end
