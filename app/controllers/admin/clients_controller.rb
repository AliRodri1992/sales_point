# frozen_string_literal: true

module Admin
  class ClientsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_client, only: %i[show edit update destroy]

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze
    SORTABLE_COLUMNS = {
      'code' => 'clients.code',
      'name' => 'clients.name',
      'email' => 'clients.email',
      'phone' => 'clients.phone',
      'rfc' => 'clients.rfc',
      'credit_limit' => 'clients.credit_limit',
      'status' => 'clients.status',
      'created_at' => 'clients.created_at'
    }.freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

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
      render :new
    end

    def create
      @client = Client.new(client_params)

      if @client.save
        redirect_to admin_clients_path, notice: t('admin.clients.created')
      else
        load_fiscal_regimes
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      render_duplicate_error
    end

    def update
      if @client.update(client_params)
        redirect_to admin_clients_path, notice: t('admin.clients.updated')
      else
        load_fiscal_regimes
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      render_duplicate_error
    end

    def destroy
      @client.update!(deleted_at: Time.current)
      redirect_to admin_clients_path, notice: t('admin.clients.destroyed')
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
      @clients = apply_sorting(@clients)
      @clients = paginate(@clients)
    end

    def filter_scope(scope)
      scope = apply_search_filter(scope)
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
      column = SORTABLE_COLUMNS.fetch(params[:sort], 'clients.name')
      direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'

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
  end
end
