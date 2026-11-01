# frozen_string_literal: true

module FinancialListingFilters
  private

  def filter_financial_listing(scope, statuses:, reference_column:)
    @filter_query = params[:q].to_s.strip.first(100)
    @filter_status = statuses.include?(params[:status]) ? params[:status] : 'all'
    scope = apply_financial_search(scope, reference_column)
    scope = scope.where(status: @filter_status) unless @filter_status == 'all'
    scope
  end

  def apply_financial_search(scope, reference_column)
    return scope if @filter_query.blank?

    search = "%#{ActiveRecord::Base.sanitize_sql_like(@filter_query)}%"
    reference = scope.klass.arel_table[reference_column].matches(search)
    supplier_name = Supplier.arel_table[:name].matches(search)
    scope.joins(:supplier).where(reference.or(supplier_name))
  end
end
