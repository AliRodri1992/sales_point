# frozen_string_literal: true

module Admin
  class CategoriesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    include CatalogAuthorization
    include CatalogNavigation
    include Admin::CategoryMutations
    include Admin::CategoryReferenceTransfers

    before_action :require_organization
    before_action :set_category, if: -> { %w[show edit update destroy references reassign].include?(action_name) }

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

      return scope unless Category.statuses.key?(params[:status].to_s)

      scope.where(status: params[:status])
    end

    def apply_sorting(scope)
      sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'name'
      sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'

      scope.order(sort_column => sort_direction, id: :asc)
    end

    def paginate(scope)
      page = (params[:page] || 1).to_i
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
      table_page_size_for('categories')
    end

    def category_in_use_response
      message_key = @category.inactive? ? 'admin.categories.references.in_use' : 'admin.categories.in_use'
      feedback = {
        swal_message: t(message_key), swal_title: t('admin.categories.in_use_title'),
        swal_icon: 'warning', swal_mode: 'modal', swal_confirm_label: t('admin.categories.show.close'),
        swal_presentation: 'category-in-use'
      }
      respond_to do |format|
        format.html do
          redirect_to admin_categories_path(request.query_parameters), flash: feedback, status: :see_other
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.append('flash', partial: 'admin/shared/swal_feedback', locals: feedback),
                 status: :unprocessable_content
        end
      end
    end

    def forbidden
      head :forbidden
    end
  end
end
