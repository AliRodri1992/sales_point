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
