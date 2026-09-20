# frozen_string_literal: true

module Admin
  class AreasController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_area, only: %i[show edit update destroy]

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    SORTABLE_COLUMNS = %w[name code status created_at updated_at].freeze

    def index
      load_areas
    end

    def show; end

    def new
      @area = Area.new
    end

    def edit; end

    def create
      @area = Area.new(area_params)

      if @area.save
        load_areas
        notify_area(current_user, @area, 'created')
        broadcast_areas_update
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.areas.created') }
          format.html do
            redirect_to admin_areas_path(request.query_parameters), notice: t('admin.areas.created')
          end
        end
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @area.update(area_params)
        load_areas
        notify_area(current_user, @area, 'updated')
        broadcast_areas_update
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.areas.updated') }
          format.html do
            redirect_to admin_areas_path(request.query_parameters), notice: t('admin.areas.updated')
          end
        end
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @area.update!(deleted_at: Time.current)
      load_areas
      notify_area(current_user, @area, 'destroyed')
      broadcast_areas_update
      respond_to do |format|
        format.turbo_stream { @swal_message = t('admin.areas.destroyed') }
        format.html do
          redirect_to admin_areas_path(request.query_parameters), notice: t('admin.areas.destroyed')
        end
      end
    end

    private

    def set_area
      @area = Area.not_deleted.find(params[:id])
    end

    def area_params
      params.expect(area: %i[name code status])
    end

    def notify_area(user, area, action)
      AreaNotification
        .with(action: action, record: area, user: user)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end

    # Broadcasts a refreshed areas catalog to every subscribed client
    # so changes are visible in real-time across devices (not just the
    # requesting client that receives the HTTP turbo_stream response).
    def broadcast_areas_update
      total_count = Area.not_deleted.count
      areas = Area.not_deleted.order(:name).limit(PER_PAGE)
      total_pages = [(total_count / PER_PAGE.to_f).ceil, 1].max
      html = render_to_string(partial: 'admin/areas/list', formats: [:html],
                              locals: { areas:, total_count:, total_pages: })
      Turbo::StreamsChannel.broadcast_update_to('areas_catalog',
                                                target: 'areas_list', html: html)
    end

    def load_areas
      @areas = filter_scope(Area.not_deleted)
      @total_count = @areas.count
      @areas = apply_sorting(@areas)
      @areas = paginate(@areas)
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
