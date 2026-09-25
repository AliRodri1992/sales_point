# frozen_string_literal: true

module Admin
  class SuppliersController < ApplicationController
    include Pundit::Authorization

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier, only: %i[show edit update destroy]
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze
    SORTABLE_COLUMNS = {
      'code' => 'suppliers.code',
      'name' => 'suppliers.name',
      'email' => 'suppliers.email',
      'phone' => 'suppliers.phone',
      'rfc' => 'suppliers.rfc',
      'status' => 'suppliers.status',
      'created_at' => 'suppliers.created_at'
    }.freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    def index
      authorize Supplier, :index?
      load_suppliers
    end

    def show
      authorize @supplier
    end

    def new
      @supplier = Supplier.new
      authorize @supplier
      load_fiscal_regimes
    end

    def edit
      authorize @supplier
      load_fiscal_regimes
      render :new
    end

    def create
      @supplier = Supplier.new(supplier_params)
      authorize @supplier

      if @supplier.save
        notify_supplier('created')
        broadcast_suppliers_update
        redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.created') }
      else
        load_fiscal_regimes
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      render_duplicate_error
    end

    def update
      authorize @supplier

      if @supplier.update(supplier_params)
        notify_supplier('updated')
        broadcast_suppliers_update
        redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.updated') }
      else
        load_fiscal_regimes
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      render_duplicate_error
    end

    def destroy
      authorize @supplier
      @supplier.update!(deleted_at: Time.current)
      notify_supplier('destroyed')
      broadcast_suppliers_update
      redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.destroyed') }
    end

    private

    def set_supplier
      @supplier = Supplier.not_deleted.includes(:sat_fiscal_regime).find(params[:id])
    end

    def load_fiscal_regimes
      @fiscal_regimes = SatFiscalRegime.current.order(:code)
    end

    def supplier_params
      params.expect(
        supplier: %i[code name email phone rfc sat_fiscal_regime_id postal_code status notes]
      )
    end

    def load_suppliers
      @suppliers = filter_scope(Supplier.not_deleted.includes(:sat_fiscal_regime))
      @total_count = @suppliers.count
      @suppliers = apply_sorting(@suppliers)
      @suppliers = paginate(@suppliers)
    end

    def filter_scope(scope)
      scope = apply_search_filter(scope)
      apply_status_filter(scope)
    end

    def apply_search_filter(scope)
      return scope if params[:search].blank?

      term = "%#{params[:search]}%"
      search_sql = [
        'suppliers.code ILIKE :q',
        'suppliers.name ILIKE :q',
        'suppliers.email ILIKE :q',
        'suppliers.phone ILIKE :q',
        'suppliers.rfc ILIKE :q'
      ].join(' OR ')

      scope.where(search_sql, q: term)
    end

    def apply_status_filter(scope)
      return scope unless params[:status].present? && params[:status] != 'all'

      scope.where(status: params[:status])
    end

    def apply_sorting(scope)
      column = SORTABLE_COLUMNS.fetch(params[:sort], 'suppliers.name')
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

    def notify_supplier(action)
      SupplierNotification
        .with(action: action, record: @supplier, user: current_user)
        .deliver(current_user, enqueue_job: false)

      current_user.broadcast_notifications_refresh
    end

    def broadcast_suppliers_update
      total_count = Supplier.not_deleted.count
      suppliers = Supplier.not_deleted.includes(:sat_fiscal_regime).order(:name).limit(PER_PAGE)
      total_pages = [(total_count / PER_PAGE.to_f).ceil, 1].max
      html = render_to_string(
        partial: 'admin/suppliers/list',
        formats: [:html],
        locals: { suppliers:, total_count:, total_pages: }
      )

      Turbo::StreamsChannel.broadcast_update_to(
        'suppliers_catalog',
        target: 'suppliers_list',
        html:
      )
    end

    def render_duplicate_error
      @supplier.errors.add(:base, t('admin.suppliers.errors.duplicate'))
      load_fiscal_regimes
      render :new, status: :unprocessable_content
    end

    def user_not_authorized
      redirect_to admin_suppliers_path, status: :forbidden,
                  alert: t('admin.suppliers.errors.unauthorized')
    end
  end
end
