# frozen_string_literal: true

module Admin
  module UnitsOfMeasureListing
    SORTABLE_COLUMNS = %w[name code abbreviation decimal_precision status created_at].freeze

    private

    def load_units
      scope = scoped_units
      count_units(scope)
      scope = filtered_units(scope)
      @total_count = scope.count
      paginate_units(scope)
      @sat_filter_options = linked_sat_keys.map do |key|
        label = "#{key.code} — #{key.description}"
        label = "#{label} (#{t('admin.units_of_measure.sat.invalid_suffix')})" unless key.active? && key.valid_for_date?
        [label, key.id]
      end
    end

    def count_units(scope)
      @unfiltered_count = scope.count
      @active_count = scope.where(status: 'active').count
      @fractional_count = scope.where('decimal_precision > 0').count
      @invalid_sat_count = scope.where.not(sat_unit_key_id: SatUnitKey.current.select(:id)).count
    end

    def filtered_units(scope)
      scope = search_units(scope) if params[:search].present?
      scope = scope.where(status: params[:status]) if UnitOfMeasure.statuses.key?(params[:status])
      filter_sat_health(filter_fractional(filter_sat_key(scope)))
    end

    def filter_sat_key(scope)
      return scope unless params[:sat_unit_key_id].to_s.match?(/\A\d+\z/)

      scope.where(sat_unit_key_id: params[:sat_unit_key_id])
    end

    def filter_fractional(scope)
      case params[:fractional]
      when 'yes' then scope.where('decimal_precision > 0')
      when 'no' then scope.where(decimal_precision: 0)
      else scope
      end
    end

    def filter_sat_health(scope)
      keys = SatUnitKey.current.select(:id)
      case params[:sat_health]
      when 'current' then scope.where(sat_unit_key_id: keys)
      when 'invalid' then scope.where.not(sat_unit_key_id: keys)
      else scope
      end
    end

    def linked_sat_keys
      SatUnitKey.with_deleted.where(id: scoped_units.select(:sat_unit_key_id))
                .order(:code).to_a
    end

    def search_units(scope)
      query = "%#{UnitOfMeasure.sanitize_sql_like(params[:search].to_s.strip.first(100))}%"
      scope.left_joins(:sat_unit_key).where(
        'units_of_measure.name ILIKE :q OR units_of_measure.code ILIKE :q OR ' \
        'units_of_measure.abbreviation ILIKE :q OR sat_unit_keys.code ILIKE :q', q: query
      )
    end

    def paginate_units(scope)
      @per_page = table_page_size_for('units_of_measure')
      @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
      @current_page = params[:page].to_i.clamp(1, @total_pages)
      @units = sorted_units(scope).includes(:sat_unit_key)
                                  .limit(@per_page).offset((@current_page - 1) * @per_page)
    end

    def sorted_units(scope)
      column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'name'
      direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
      scope.order(column => direction, id: :asc)
    end
  end
end
