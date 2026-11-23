# frozen_string_literal: true

module PromotionsHelper
  CAMPAIGN_FILTERS = %i[search status currency benefit_kind product_id category_id customer_segment
                        validity usage].freeze
  CAMPAIGN_STATES = %w[draft scheduled active paused exhausted expired archived].freeze
  FILTER_OPTIONS = { status: CAMPAIGN_STATES, validity: %w[current upcoming ended],
                     usage: %w[available exhausted], benefit_kind: %w[percentage fixed_amount] }.freeze
  TARGET_KINDS = { 'product' => :product, 'excluded_product' => :product,
                   'category' => :category, 'excluded_category' => :category }.freeze
  RULE_FIELDS = { 'min_quantity' => :quantity, 'min_subtotal' => :amount,
                  'customer_segment' => :customer_segment }.freeze
  ACTION_ICONS = { 'activate' => 'play', 'resume' => 'play', 'pause' => 'pause',
                   'archive' => 'archive', 'duplicate' => 'copy' }.freeze

  def promotion_icon(name, **)
    delta_icon("promotion-#{name}", stroke_width: 1.7, focusable: false, **)
  end

  def campaign_text(key, **)
    t("admin.promotion_campaigns.#{key}", **)
  end

  def campaign_filters
    params.permit(*CAMPAIGN_FILTERS, :sort, :direction, :per_page).to_h.compact_blank
  end

  def campaign_navigation_params
    campaign_filters.merge(params.permit(:page).to_h.compact_blank)
  end

  def campaign_choices(group, values)
    values.map { |value| [campaign_text("#{group}.#{value}"), value] }
  end

  def campaign_filter_value(field, value, selected_labels = {})
    return selected_labels[field.to_s] if selected_labels.key?(field.to_s)
    return value unless FILTER_OPTIONS[field.to_sym]&.include?(value)
    return t("admin.catalog_design.benefit_#{value}") if field.to_s == 'benefit_kind'

    campaign_text("#{field}.#{value}")
  end

  def campaign_currency_options
    Currency.active.order(:code).pluck(:name, :code).map do |name, code|
      ["#{code} · #{name}", code]
    end
  end

  def campaign_currency_places
    Currency.with_deleted.pluck(:code, :decimal_places).to_h
  end

  def campaign_money(amount, currency, precision)
    number_to_currency(amount, unit: currency, format: '%n %u', precision:)
  end

  def campaign_benefit_label(benefit, currency, precision)
    return campaign_money(benefit.value, currency, precision) unless benefit.percentage?

    number_to_percentage(benefit.value, precision: 4, strip_insignificant_zeros: true)
  end

  def campaign_condition_label(kind)
    campaign_text("conditions.#{kind}", default: t("admin.catalog_design.condition_#{kind}", default: kind.to_s))
  end

  def campaign_target_name(condition, target)
    record = condition.public_send(target)
    record.name if record&.organization_id == current_organization.id
  end

  def campaign_condition_value(condition, currency, precision)
    target = TARGET_KINDS[condition.kind]
    return campaign_target_name(condition, target) || campaign_text('unavailable') if target
    return campaign_money(condition.amount, currency, precision) if condition.kind_min_subtotal?

    field = RULE_FIELDS[condition.kind]
    condition.public_send(field) if field
  end

  def campaign_date(time, format: :short)
    time ? l(time.in_time_zone, format:) : t('admin.catalog_design.no_limit')
  end

  def campaign_available_actions(record)
    %w[activate pause resume archive duplicate].select do |action|
      policy(record).public_send("#{action}?") && record.transition_available?(action)
    end
  end
end
