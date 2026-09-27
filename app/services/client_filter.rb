# frozen_string_literal: true

class ClientFilter
  SORTABLE_COLUMNS = {
    'code' => 'clients.code',
    'name' => 'clients.name',
    'email' => 'clients.email',
    'phone' => 'clients.phone',
    'rfc' => 'clients.rfc',
    'credit_limit' => 'clients.credit_limit',
    'status' => 'clients.status',
    'created_at' => 'clients.created_at'
  }.freeze

  SORT_DIRECTIONS = %w[asc desc].freeze

  def initialize(scope, params)
    @scope = scope
    @params = params
  end

  def call
    result = @scope
    result = apply_search_filter(result)
    result = apply_status_filter(result)
    apply_sorting(result)
  end

  private

  def apply_search_filter(scope)
    return scope if @params[:search].blank?

    term = "%#{@params[:search]}%"
    search_sql = [
      'clients.code ILIKE :q',
      'clients.name ILIKE :q',
      'clients.email ILIKE :q',
      'clients.phone ILIKE :q',
      'clients.rfc ILIKE :q'
    ].join(' OR ')

    scope.where(search_sql, q: term)
  end

  def apply_status_filter(scope)
    return scope unless @params[:status].present? && @params[:status] != 'all'

    scope.where(status: @params[:status])
  end

  def apply_sorting(scope)
    column = SORTABLE_COLUMNS.fetch(@params[:sort], 'clients.name')
    direction = SORT_DIRECTIONS.include?(@params[:direction]) ? @params[:direction] : 'asc'

    scope.order(column => direction)
  end
end
