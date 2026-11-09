# frozen_string_literal: true

module Admin
  module ClientsListing
    private

    def load_clients
      base = scoped_clients
      @unfiltered_count = base.count
      @active_count = base.where(status: :active).count
      @credit_count = base.where('credit_limit > 0').count
      @clients = ClientFilter.new(base, params).call
      @total_count = @clients.count
      @clients = paginate(@clients.includes(:sat_fiscal_regime, :phones))
    end

    def paginate(scope)
      page = params[:page].to_i
      page = 1 if page < 1
      per_page = per_page_param
      @per_page = per_page
      @total_pages = [(@total_count / per_page.to_f).ceil, 1].max
      page = @total_pages if page > @total_pages
      @current_page = page

      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      table_page_size_for('clients')
    end

  end
end
