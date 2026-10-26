# frozen_string_literal: true

module FinancialListingFilters
  private

  def filter_financial_listing(scope, statuses:, reference_column:)
    @filter_query = params[:q].to_s.strip.first(100)
    @filter_status = statuses.include?(params[:status]) ? params[:status] : 'all'

    if @filter_query.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@filter_query)
      search = "%#{escaped}%"
      reference = scope.klass.arel_table[reference_column]
      supplier_name = Supplier.arel_table[:name]
      scope = scope.joins(:supplier).where(reference.matches(search).or(supplier_name.matches(search)))
    end

    scope = scope.where(status: @filter_status) unless @filter_status == 'all'
    scope
  end
end
