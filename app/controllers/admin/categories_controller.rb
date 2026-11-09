# frozen_string_literal: true

module Admin
  class CategoriesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    include CatalogAuthorization
    include CatalogNavigation
    include Admin::CategoryMutations

    before_action :require_organization
    before_action :set_category, only: %i[show edit update destroy]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden

    PER_PAGE = 10
    PER_PAGE_OPTIONS = TablePagePreference::OPTIONS

    SORTABLE_COLUMNS = %w[name code status created_at updated_at].freeze

    def index
      load_categories
    end

    def show; end

    def new
      @category = Category.new
    end

    def edit; end

    private

    def set_category
      @category = scoped_categories.find(params[:id])
    end

    def scoped_categories
      current_organization.categories.not_deleted
    end

    def require_organization
      head :forbidden unless current_organization
    end

    def category_params
      params.expect(category: %i[name code description status])
    end

    def notify_category(user, category, action)
      CategoryNotification
        .with(action: action, record: category, user: user)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end

    # Broadcasts a refreshed categories catalog to every subscribed client
    # so changes are visible in real-time across devices (not just the
    # requesting client that receives the HTTP turbo_stream response).
    def broadcast_categories_update
      # Each browser refreshes its own URL, keeping the user's saved page size.
      Turbo::StreamsChannel.broadcast_refresh_to("categories_catalog_#{current_organization.id}")
    end

    def load_categories
      @unfiltered_count = scoped_categories.count
      @categories = filter_scope(scoped_categories)
      @total_count = @categories.count
      @categories = apply_sorting(@categories)
      @categories = paginate(@categories)
    end

    def filter_scope(scope)
      if params[:search].present?
        q = "%#{Category.sanitize_sql_like(params[:search].to_s.strip.first(100))}%"
        scope = scope.where('name ILIKE :q OR code ILIKE :q', q:)
      end

      return scope unless params[:status].present? && params[:status] != 'all'

      scope.where(status: params[:status])
    end

    def apply_sorting(scope)
      sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'name'
      sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'

      scope.order(sort_column => sort_direction)
    end

    def paginate(scope)
      page = (params[:page] || 1).to_i
      page = 1 if page < 1
      per_page = per_page_param
      @per_page = per_page

      @total_pages = (scope.count / per_page.to_f).ceil
      @total_pages = 1 if @total_pages < 1
      page = @total_pages if page > @total_pages

      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      table_page_size_for('categories')
    end

    def category_in_use_response
      message = t('admin.categories.in_use')
      respond_to do |format|
        format.html { redirect_to admin_categories_path, alert: message, status: :see_other }
        format.turbo_stream do
          content = view_context.tag.div(
            message, role: 'alert',
                     class: 'rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800'
          )
          render turbo_stream: turbo_stream.update('categories_alert', content), status: :unprocessable_content
        end
      end
    end

    def forbidden
      head :forbidden
    end
  end
end
