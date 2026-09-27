# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
module Admin
  class ClientsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_client, only: %i[show edit update destroy]

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    def index
      load_clients
    end

    def show; end

    def new
      @client = Client.new
      load_fiscal_regimes
    end

    def edit
      load_fiscal_regimes
    end

    def create
      @client = Client.new(client_params)

      if @client.save
        notify_client(current_user, @client, 'created')
        redirect_to admin_clients_path, flash: { swal_message: t('admin.clients.created') }
      else
        load_fiscal_regimes
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      render_duplicate_error
    end

    def update
      if @client.update(client_params)
        notify_client(current_user, @client, 'updated')
        redirect_to admin_clients_path, flash: { swal_message: t('admin.clients.updated') }
      else
        load_fiscal_regimes
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      render_duplicate_error
    end

    def destroy
      @client.update!(deleted_at: Time.current)
      notify_client(current_user, @client, 'destroyed')

      respond_to do |format|
        format.turbo_stream { @swal_message = t('admin.clients.destroyed') }
        format.html do
          redirect_to admin_clients_path,
                      flash: { swal_message: t('admin.clients.destroyed') }
        end
      end
    end

    private

    def set_client
      @client = Client.not_deleted.includes(:sat_fiscal_regime).find(params[:id])
    end

    def load_fiscal_regimes
      @fiscal_regimes = SatFiscalRegime.current.order(:code)
    end

    def client_params
      params.expect(
        client: %i[
          code name email phone rfc sat_fiscal_regime_id
          postal_code credit_limit status notes
        ]
      )
    end

    def load_clients
      @clients = filter_scope(Client.not_deleted.includes(:sat_fiscal_regime))
      @total_count = @clients.count
      @clients = ClientFilter.new(@clients, params).call
      @clients = paginate(@clients)
    end

    def filter_scope(scope)
      apply_search_filter(scope)
      apply_status_filter(scope)
    end

    def apply_search_filter(scope)
      return scope if params[:search].blank?

      term = "%#{params[:search]}%"
      search_sql = [
        'clients.code ILIKE :q',
        'clients.name ILIKE :q',
        'clients.email ILIKE :q',
        'clients.phone ILIKE :q',
        'clients.rfc ILIKE :q'
      ].join(' OR ')

      scope.where(search_sql, q: term)
    end

    def apply_status_filter(scope)
      return scope unless params[:status].present? && params[:status] != 'all'

      scope.where(status: params[:status])
    end

    def apply_sorting(scope)
      column = ClientFilter::SORTABLE_COLUMNS.fetch(params[:sort], 'clients.name')
      direction = ClientFilter::SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'

      scope.order(column => direction)
    end

    def paginate(scope)
      page = params[:page].to_i
      page = 1 if page < 1
      per_page = per_page_param
      @total_pages = [(@total_count / per_page.to_f).ceil, 1].max
      page = @total_pages if page > @total_pages

      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      value = params[:per_page].to_i
      PER_PAGE_OPTIONS.include?(value) ? value : PER_PAGE
    end

    def render_duplicate_error
      @client.errors.add(:base, t('admin.clients.errors.duplicate'))
      load_fiscal_regimes
      render :new, status: :unprocessable_content
    end

    def notify_client(user, client, action)
      ClientNotification
        .with(action: action, record: client, user:)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end
  end
  # rubocop:enable Metrics/ClassLength
end
