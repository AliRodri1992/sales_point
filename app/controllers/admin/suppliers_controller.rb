# frozen_string_literal: true

module Admin
  class SuppliersController < ApplicationController
    include Pundit::Authorization
    include SuppliersListing

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :require_supplier_organization!
    before_action :set_supplier, only: %i[show edit update destroy]
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    def index
      authorize Supplier, :index?
      load_suppliers
      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace('supplier_active_filters', partial: 'admin/suppliers/active_filters_frame'),
            turbo_stream.replace('suppliers_list', partial: 'admin/suppliers/list_frame')
          ]
        end
      end
    end

    def export
      authorize Supplier, :index?
      @supplier_regimes = SatFiscalRegime.current.order(:code)
      scope = policy_scope(current_organization.suppliers.not_deleted)
      scope = apply_sorting(apply_filters(scope))
      format = params[:file_format].to_s
      return head :bad_request unless %w[pdf xlsx].include?(format)

      report = supplier_export_report(scope)
      send_supplier_export(report, format)
    end

    def show
      authorize @supplier
    end

    def new
      @supplier = current_organization.suppliers.new
      authorize @supplier
      load_fiscal_regimes
    end

    def edit
      authorize @supplier
      load_fiscal_regimes
      render :new
    end

    def create
      @supplier = current_organization.suppliers.new(supplier_params)
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
      @supplier.errors.add(:base, t('admin.suppliers.errors.duplicate'))
      load_fiscal_regimes
      render :new, status: :unprocessable_content
    end

    def update
      authorize @supplier

      if @supplier.update(supplier_update_attributes)
        notify_supplier('updated')
        broadcast_suppliers_update
        redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.updated') }
      else
        load_fiscal_regimes
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @supplier.errors.add(:base, t('admin.suppliers.errors.duplicate'))
      load_fiscal_regimes
      render :new, status: :unprocessable_content
    end

    def destroy
      authorize @supplier
      @supplier.update!(deleted_at: Time.current)
      notify_supplier('destroyed')
      broadcast_suppliers_update
      redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.destroyed') }
    end

    private

    def supplier_export_report(scope)
      Reports::Definitions::SuppliersReport.new(
        scope:, organization: current_organization, user: current_user, locale: I18n.locale
      )
    end

    def send_supplier_export(report, format)
      mime = if format == 'pdf'
               'application/pdf'
             else
               'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
             end
      contents = Reports::ExportService.call(report:, format:)
      send_data contents, filename: "#{report.filename}.#{format}", type: mime, disposition: 'attachment'
    end

    def require_supplier_organization!
      head :forbidden unless current_organization
    end

    def set_supplier
      @supplier = policy_scope(
        current_organization.suppliers.not_deleted.includes(:sat_fiscal_regime)
      ).find(params[:id])
    end

    def load_fiscal_regimes
      @fiscal_regimes = SatFiscalRegime.current.order(:code)
    end

    def supplier_params
      params.expect(
        supplier: [
          :code, :name, :legal_name, :trade_name, :alias_name, :classification, :person_type,
          :email, :phone, :rfc, :sat_fiscal_regime_id, :postal_code, :status, :notes,
          :currency, :credit_days, :credit_limit, :discount_percent, :minimum_order_amount,
          :responsible_user_id, :tags_text, { documents: [] }
        ]
      )
    end

    def supplier_update_attributes
      attributes = supplier_params
      uploads = attributes.delete(:documents)
      attributes[:documents] = @supplier.documents.blobs.to_a + uploads if uploads.present?
      attributes
    end

    def notify_supplier(action)
      Suppliers::NotifyService.call(action:, supplier: @supplier, user: current_user)
    end

    def user_not_authorized
      redirect_to admin_suppliers_path, status: :forbidden,
                                        alert: t('admin.suppliers.errors.unauthorized')
    end
  end
end
