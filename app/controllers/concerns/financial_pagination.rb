# frozen_string_literal: true

module FinancialPagination
  include FinancialListingFilters

  private

  def paginate_filtered_financial(scope, includes:, reference_column:)
    filtered = filter_financial_listing(scope, statuses: scope.klass.statuses.keys, reference_column:)
    paginate_financial(filtered, includes:)
  end

  def paginate_financial(scope, includes:)
    @total_records = scope.count
    @total_pages = [(@total_records.to_f / 20).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    scope.includes(*includes).order(created_at: :desc, id: :desc)
         .limit(20).offset((@page - 1) * 20)
  end
end
