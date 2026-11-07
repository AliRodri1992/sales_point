# frozen_string_literal: true

module Admin
  module LanguagesListing
    private

    def load_languages
      @languages = filter_scope(Language.not_deleted)
      @total_count = @languages.count
      @languages = apply_sorting(@languages)
      @languages = paginate(@languages)
    end

    def filter_scope(scope)
      if params[:search].present?
        scope = scope.where('name ILIKE :q OR code ILIKE :q',
                            q: "%#{Language.sanitize_sql_like(params[:search].to_s.strip)}%")
      end

      return scope unless params[:status].present? && params[:status] != 'all'

      scope.where(status: params[:status])
    end

    def apply_sorting(scope)
      sort_column = Admin::LanguagesController::SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'name'
      sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'

      scope.order(sort_column => sort_direction)
    end

    def paginate(scope)
      page = params[:page].to_s.to_i
      page = 1 if page < 1
      per_page = per_page_param
      @per_page = per_page

      @total_pages = (scope.count / per_page.to_f).ceil
      @total_pages = 1 if @total_pages < 1
      page = @total_pages if page > @total_pages

      @current_page = page
      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      table_page_size_for('languages')
    end
  end
end
