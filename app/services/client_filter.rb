# frozen_string_literal: true

class ClientFilter
  SORTABLE_COLUMNS = {
    'code' => 'clients.code',
    'name' => 'clients.name',
    'email' => 'clients.email',
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
    scope = search(@scope)
    scope = status(scope)
    scope = credit(scope)
    scope = fiscal_identifier(scope)
    scope = fiscal_regime(scope)
    sort(scope)
  end

  private

  def search(scope)
    term = @params[:search].to_s.strip.first(100)
    return scope if term.blank?

    wildcard = "%#{Client.sanitize_sql_like(term)}%"
    scope.where(<<~SQL.squish, q: wildcard)
      clients.code ILIKE :q OR clients.name ILIKE :q OR clients.email ILIKE :q
      OR clients.rfc ILIKE :q OR EXISTS (
        SELECT 1 FROM phones
        WHERE phones.phoneable_type = 'Client' AND phones.phoneable_id = clients.id
          AND phones.deleted_at IS NULL AND phones.number ILIKE :q
      )
    SQL
  end

  def status(scope)
    return scope unless Client.statuses.key?(@params[:status])

    scope.where(status: @params[:status])
  end

  def credit(scope)
    case @params[:credit]
    when 'yes' then scope.where('clients.credit_limit > 0')
    when 'no' then scope.where(credit_limit: 0)
    else scope
    end
  end

  def fiscal_identifier(scope)
    case @params[:rfc]
    when 'yes' then scope.where.not(rfc: [nil, ''])
    when 'no' then scope.where(rfc: [nil, ''])
    else scope
    end
  end

  def fiscal_regime(scope)
    id = @params[:sat_fiscal_regime_id].to_s
    return scope unless id.match?(/\A[1-9]\d*\z/)

    scope.where(sat_fiscal_regime_id: id.to_i)
  end

  def sort(scope)
    column = SORTABLE_COLUMNS.fetch(@params[:sort], 'clients.name')
    direction = SORT_DIRECTIONS.include?(@params[:direction]) ? @params[:direction] : 'asc'
    scope.order(Arel.sql("#{column} #{direction}"), id: :asc)
  end
end
