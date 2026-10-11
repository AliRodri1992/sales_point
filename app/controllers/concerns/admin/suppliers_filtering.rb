# frozen_string_literal: true

module Admin
  module SuppliersFiltering
    FILTER_VALUES = {
      classification: %w[manufacturer distributor wholesaler service other],
      person_type: %w[individual company],
      currency: %w[MXN USD EUR]
    }.freeze
    NUMERIC_FIELDS = %w[credit_days credit_limit minimum_order_amount discount_percent].freeze
    DATE_FIELDS = %w[created_at updated_at].freeze
    NUMERIC_BOUNDS = %w[min max].freeze
    DATE_BOUNDS = %w[from to].freeze

    private

    def apply_filters(scope)
      scope = apply_search_filter(scope)
      scope = apply_select_filters(scope)
      scope = apply_reference_filters(scope)
      scope = apply_credit_filter(scope)
      scope = apply_numeric_filters(scope)
      apply_date_filters(scope)
    end

    def apply_search_filter(scope)
      return scope if params[:search].blank?

      scope.search(params[:search])
    end

    def apply_select_filters(scope)
      scope = scope.with_status(params[:status]) if %w[active inactive].include?(params[:status])
      FILTER_VALUES.each do |field, values|
        scope = scope.where(field => params[field]) if values.include?(params[field])
      end
      scope
    end

    def apply_reference_filters(scope)
      scope = scope.where(sat_fiscal_regime_id: params[:sat_fiscal_regime_id]) if valid_regime_filter?
      scope = scope.where(responsible_user_id: params[:responsible_user_id]) if valid_responsible_filter?
      scope
    end

    def valid_regime_filter?
      return false unless valid_id?(:sat_fiscal_regime_id)

      @supplier_regimes.any? { |regime| regime.id.to_s == params[:sat_fiscal_regime_id].to_s }
    end

    def valid_responsible_filter?
      valid_id?(:responsible_user_id) &&
        current_organization.users.exists?(id: params[:responsible_user_id])
    end

    def apply_credit_filter(scope)
      case params[:credit]
      when 'yes' then scope.where('credit_limit > 0')
      when 'no' then scope.where(credit_limit: [0, nil])
      else scope
      end
    end

    def apply_numeric_filters(scope)
      NUMERIC_FIELDS.each do |field|
        NUMERIC_BOUNDS.each do |bound|
          scope = apply_numeric_bound(scope, field, bound)
        end
      end
      scope
    end

    def apply_numeric_bound(scope, field, bound)
      return scope unless NUMERIC_FIELDS.include?(field)

      key = "#{field}_#{bound}"
      return scope unless valid_nonnegative_number?(key)

      operator = bound == 'min' ? '>=' : '<='
      scope.where("suppliers.#{field} #{operator} ?", BigDecimal(params[key].to_s))
    end

    def apply_date_filters(scope)
      DATE_FIELDS.each do |field|
        DATE_BOUNDS.each do |bound|
          scope = apply_date_bound(scope, field, bound)
        end
      end
      scope
    end

    def apply_date_bound(scope, field, bound)
      return scope unless DATE_FIELDS.include?(field)

      key = "#{field}_#{bound}"
      return scope if params[key].blank?

      date = parse_filter_date(params[key])
      return scope unless date

      value = bound == 'from' ? date.beginning_of_day : date.end_of_day
      operator = bound == 'from' ? '>=' : '<='
      scope.where("suppliers.#{field} #{operator} ?", value)
    end

    def parse_filter_date(value)
      Date.iso8601(value)
    rescue Date::Error
      nil
    end

    def valid_id?(key)
      params[key].to_s.match?(/\A[1-9]\d*\z/)
    end

    def valid_nonnegative_number?(key)
      params[key].to_s.match?(/\A\d{1,12}(?:\.\d{1,2})?\z/)
    end
  end
end
