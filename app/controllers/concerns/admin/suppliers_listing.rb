# frozen_string_literal: true

module Admin
  module SuppliersListing
    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    SORTABLE_COLUMNS = {
      'code' => 'suppliers.code',
      'name' => 'suppliers.name',
      'email' => 'suppliers.email',
      'phone' => 'suppliers.phone',
      'rfc' => 'suppliers.rfc',
      'status' => 'suppliers.status',
      'created_at' => 'suppliers.created_at'
    }.freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    private

    def load_suppliers
      base_scope = policy_scope(current_organization.suppliers.not_deleted)
      @supplier_stats = {
        total: base_scope.count,
        active: base_scope.where(status: 'active').count,
        inactive: base_scope.where(status: 'inactive').count,
        credit: base_scope.where('credit_limit > 0').count
      }
      @supplier_regimes = SatFiscalRegime.current.order(:code)
      @suppliers = apply_filters(base_scope.includes(:sat_fiscal_regime))
      @total_count = @suppliers.count
      @suppliers = apply_sorting(@suppliers)
      @suppliers = paginate(@suppliers)
    end

    def apply_filters(scope)
      scope = scope.search(params[:search]) if params[:search].present?
      scope = scope.with_status(params[:status]) if %w[active inactive].include?(params[:status])
      allowed_filters = {
        classification: %w[manufacturer distributor wholesaler service other],
        person_type: %w[individual company],
        currency: %w[MXN USD EUR]
      }
      allowed_filters.each do |field, values|
        scope = scope.where(field => params[field]) if values.include?(params[field])
      end
      scope = scope.where(sat_fiscal_regime_id: params[:sat_fiscal_regime_id]) if valid_id?(:sat_fiscal_regime_id)
      scope = scope.where(responsible_user_id: params[:responsible_user_id]) if valid_id?(:responsible_user_id)
      scope = scope.where('credit_limit > 0') if params[:credit] == 'yes'
      scope = scope.where(credit_limit: 0) if params[:credit] == 'no'

      %w[credit_days credit_limit minimum_order_amount discount_percent].each do |field|
        %w[min max].each do |bound|
          key = "#{field}_#{bound}"
          next unless valid_nonnegative_number?(key)

          operator = bound == 'min' ? '>=' : '<='
          scope = scope.where("suppliers.#{field} #{operator} ?", BigDecimal(params[key].to_s))
        end
      end

      %w[created_at updated_at].each do |field|
        %w[from to].each do |bound|
          key = "#{field}_#{bound}"
          date = Date.iso8601(params[key]) rescue nil
          next unless date

          scope = scope.where("suppliers.#{field} #{bound == 'from' ? '>=' : '<='} ?",
                              bound == 'from' ? date.beginning_of_day : date.end_of_day)
        end
      end
      scope
    end

    def valid_id?(key)
      params[key].to_s.match?(/\A[1-9]\d*\z/)
    end

    def valid_nonnegative_number?(key)
      params[key].to_s.match?(/\A\d{1,12}(?:\.\d{1,2})?\z/)
    end

    def apply_sorting(scope)
      column = SORTABLE_COLUMNS.fetch(params[:sort], 'suppliers.name')
      direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'
      scope.order(column => direction)
    end

    def paginate(scope)
      page = [params[:page].to_i, 1].max
      per_page = per_page_param
      @total_pages = [(@total_count / per_page.to_f).ceil, 1].max
      page = @total_pages if page > @total_pages

      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      value = params[:per_page].to_i
      PER_PAGE_OPTIONS.include?(value) ? value : PER_PAGE
    end

    def broadcast_suppliers_update
      Turbo::StreamsChannel.broadcast_refresh_to(
        "suppliers_catalog_#{current_organization.id}"
      )
    end
  end
end
