# frozen_string_literal: true

module Admin
  class SupplierInvoicesController < ApplicationController
    include FinancialAccess
    include FinancialPagination
    include FinancialListingFilters

    before_action :set_invoice, only: %i[show edit update post_invoice cancel download_xml download_pdf match_receipts]

    def index
      authorize current_organization.supplier_invoices.new, :index?
      scope = policy_scope(current_organization.supplier_invoices)
      scope = filter_financial_listing(scope, statuses: SupplierInvoice.statuses.keys,
                                            reference_column: 'folio')
      @invoices = paginate_financial(scope, includes: %i[supplier currency account_payable])
    end

    def show
      authorize @invoice
    end

    def preview_cfdi
      @invoice = build_preview_invoice
      response.headers['Cache-Control'] = 'no-store'
      render json: AccountsPayable::PreviewCfdi.call(invoice: @invoice)
    rescue ArgumentError, ActionController::ParameterMissing, ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def new
      @invoice = new_invoice
      authorize @invoice
      load_catalogs
    end

    def edit
      authorize @invoice
      load_catalogs
    end

    def create
      @invoice = new_invoice
      authorize @invoice
      apply_attributes
      if @invoice.save
        FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                    event: 'invoice.created', subject: @invoice)
        redirect_to admin_supplier_invoice_path(@invoice)
      else
        load_catalogs
        render :new, status: :unprocessable_content
      end
    rescue ArgumentError => e
      @invoice.errors.add(:base, e.message)
      load_catalogs
      render :new, status: :unprocessable_content
    end

    def update
      authorize @invoice
      apply_attributes
      if @invoice.save
        FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                    event: 'invoice.updated', subject: @invoice)
        redirect_to admin_supplier_invoice_path(@invoice)
      else
        load_catalogs
        render :edit, status: :unprocessable_content
      end
    rescue ArgumentError => e
      @invoice.errors.add(:base, e.message)
      load_catalogs
      render :edit, status: :unprocessable_content
    end

    def post_invoice
      authorize @invoice, :post?
      AccountsPayable::PostInvoice.call(invoice: @invoice, actor: current_user)
      redirect_to admin_supplier_invoice_path(@invoice)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      financial_error(e, admin_supplier_invoice_path(@invoice))
    end

    def cancel
      authorize @invoice, :cancel?
      AccountsPayable::CancelInvoice.call(invoice: @invoice, actor: current_user)
      redirect_to admin_supplier_invoice_path(@invoice)
    rescue ArgumentError => e
      financial_error(e, admin_supplier_invoice_path(@invoice))
    end

    def match_receipts
      authorize @invoice, :update?
      receipt_ids = params.fetch(:receipt_ids, []).map(&:to_i)
      AccountsPayable::MatchReceipts.call(invoice: @invoice, receipt_ids:, actor: current_user)
      redirect_to admin_supplier_invoice_path(@invoice)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      financial_error(e, admin_supplier_invoice_path(@invoice))
    end

    def download_pdf
      authorize @invoice, :download?
      send_financial_attachment(@invoice.pdf_document, "invoice-#{@invoice.id}.pdf", 'application/pdf')
    end

    def download_xml
      authorize @invoice, :download?
      send_financial_attachment(@invoice.xml_document, "cfdi-#{@invoice.id}.xml", 'application/xml')
    end

    private

    def new_invoice
      current_organization.supplier_invoices.new(created_by: current_user)
    end

    def set_invoice
      @invoice = policy_scope(current_organization.supplier_invoices).find(params[:id])
    end

    def build_preview_invoice
      invoice = new_invoice
      authorize invoice, :create?
      invoice.supplier = current_organization.suppliers.not_deleted.find(params[:supplier_id])
      AccountsPayable::ImportCfdi.call(invoice:, xml: params.require(:xml_document).read)
    end

    def invoice_params
      params.expect(supplier_invoice: %i[
                      supplier_id purchase_order_id currency_id series folio issued_on received_on
                      due_on subtotal discount tax_amount total exchange_rate notes
                      xml_document pdf_document
                    ])
    end

    def apply_attributes
      AccountsPayable::PrepareInvoice.call(
        invoice: @invoice, attributes: invoice_params, organization: current_organization
      )
    end

    def load_catalogs
      @suppliers = current_organization.suppliers.available.order(:name)
      @currencies = Currency.active.order(:code)
      @orders = current_organization.purchase_orders.order(created_at: :desc).limit(200)
    end
  end
end
