# frozen_string_literal: true

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
      @clients = ClientFilter.new(Client.not_deleted, params).call
      @total_count = @clients.count
      @clients = @clients.includes(:sat_fiscal_regime)
      @clients = paginate(@clients)
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
end
