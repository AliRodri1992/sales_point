# frozen_string_literal: true

module Admin
  class ClientsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    include CatalogAuthorization
    include CatalogNavigation

    before_action :set_client, only: %i[show edit update destroy]

    PER_PAGE = 10
    PER_PAGE_OPTIONS = TablePagePreference::OPTIONS

    def index
      load_clients
      load_fiscal_regimes
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
      assign_phone_organization(@client)

      if @client.save
        notify_client(current_user, @client, 'created')
        return if redirect_without_catalog_listing(@client, :created)

        redirect_to admin_clients_path, flash: { swal_message: t('admin.clients.created') }
      else
        load_fiscal_regimes
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique => e
      render_duplicate_error(:new, e)
    end

    def update
      @client.assign_attributes(client_params)
      assign_phone_organization(@client)
      if @client.save
        notify_client(current_user, @client, 'updated')
        return if redirect_without_catalog_listing(@client, :updated)

        redirect_to admin_clients_path, flash: { swal_message: t('admin.clients.updated') }
      else
        load_fiscal_regimes
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique => e
      render_duplicate_error(:edit, e)
    end

    def destroy
      @client.update!(deleted_at: Time.current)
      notify_client(current_user, @client, 'destroyed')
      return if redirect_without_catalog_listing(@client, :destroyed)

      respond_to do |format|
        format.turbo_stream do
          load_clients
          @swal_message = t('admin.clients.destroyed')
        end
        format.html do
          redirect_to admin_clients_path,
                      status: :see_other,
                      flash: { swal_message: t('admin.clients.destroyed') }
        end
      end
    end

    private

    def set_client
      @client = Client.not_deleted.includes(:sat_fiscal_regime, :phones).find(params[:id])
    end

    def load_fiscal_regimes
      @fiscal_regimes = SatFiscalRegime.current.order(:code).to_a
      selected = @client&.sat_fiscal_regime
      @fiscal_regimes.unshift(selected) if selected && @fiscal_regimes.exclude?(selected)
    end

    def client_params
      params.expect(
        client: [
          :code, :name, :email, :rfc, :sat_fiscal_regime_id, :postal_code,
          :credit_limit, :status, :notes,
          { phones_attributes: [%i[id number country_code kind label extension primary whatsapp_enabled _destroy]] }
        ]
      )
    end

    def assign_phone_organization(client)
      client.phones.each do |phone|
        phone.organization ||= current_organization
      end
    end

    def load_clients
      base = Client.not_deleted
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

    def render_duplicate_error(template = :new, error = nil)
      attribute = error&.message.to_s.include?('index_clients_on_rfc') ? :rfc : :code
      @client.errors.add(attribute, t('admin.clients.errors.duplicate'))
      load_fiscal_regimes
      render template, status: :unprocessable_content
    end

    def notify_client(user, client, action)
      ClientNotification
        .with(action: action, record: client, user:)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end
  end
end
