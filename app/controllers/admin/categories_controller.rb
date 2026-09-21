# frozen_string_literal: true

module Admin
  class CategoriesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_category, only: %i[show edit update destroy]

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    SORTABLE_COLUMNS = %w[name code status created_at updated_at].freeze

    def index
      load_categories
    end

    def show; end

    def new
      @category = Category.new
    end

    def edit; end

    def create
      @category = Category.new(category_params)

      if @category.save
        load_categories
        notify_category(current_user, @category, 'created')
        broadcast_categories_update
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.categories.created') }
          format.html do
            redirect_to admin_categories_path(request.query_parameters), notice: t('admin.categories.created')
          end
        end
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @category.update(category_params)
        load_categories
        notify_category(current_user, @category, 'updated')
        broadcast_categories_update
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.categories.updated') }
          format.html do
            redirect_to admin_categories_path(request.query_parameters), notice: t('admin.categories.updated')
          end
        end
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @category.update!(deleted_at: Time.current)
      load_categories
      notify_category(current_user, @category, 'destroyed')
      broadcast_categories_update
      respond_to do |format|
        format.turbo_stream { @swal_message = t('admin.categories.destroyed') }
        format.html do
          redirect_to admin_categories_path(request.query_parameters), notice: t('admin.categories.destroyed')
        end
      end
    end

    private

    def set_category
      @category = Category.not_deleted.find(params[:id])
    end

    def category_params
      params.expect(category: %i[name code status])
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
      total_count = Category.not_deleted.count
      categories = Category.not_deleted.order(:name).limit(PER_PAGE)
      total_pages = [(total_count / PER_PAGE.to_f).ceil, 1].max
      html = render_to_string(partial: 'admin/categories/list', formats: [:html],
                              locals: { categories:, total_count:, total_pages: })
      Turbo::StreamsChannel.broadcast_update_to('categories_catalog',
                                                target: 'categories_list', html: html)
    end

    def load_categories
      @categories = filter_scope(Category.not_deleted)
      @total_count = @categories.count
      @categories = apply_sorting(@categories)
      @categories = paginate(@categories)
    end

    def filter_scope(scope)
      scope = scope.where('name ILIKE :q OR code ILIKE :q', q: "%#{params[:search]}%") if params[:search].present?

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

      @total_pages = (scope.count / per_page.to_f).ceil
      @total_pages = 1 if @total_pages < 1
      page = @total_pages if page > @total_pages

      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      per_page = params[:per_page]&.to_i
      PER_PAGE_OPTIONS.include?(per_page) ? per_page : PER_PAGE
    end
  end
end
