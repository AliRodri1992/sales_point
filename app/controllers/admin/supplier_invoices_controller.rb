# frozen_string_literal: true

module Admin
  class SupplierInvoicesController < ApplicationController
    include FinancialAccess

    before_action :set_invoice, only: %i[show edit update post_invoice cancel download_xml]

    def index
      authorize current_organization.supplier_invoices.new, :index?
      @invoices = policy_scope(current_organization.supplier_invoices)
                  .includes(:supplier, :currency, :account_payable).order(created_at: :desc)
    end

    def show
      authorize @invoice
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
      @invoice.with_lock do
        raise ArgumentError, 'Invoice already cancelled' if @invoice.cancelled?
        if @invoice.account_payable &&
           (@invoice.account_payable.supplier_payment_allocations.exists? ||
            @invoice.account_payable.supplier_credit_allocations.exists?)
          raise ArgumentError, 'Cannot cancel an invoice with financial movements'
        end

        @invoice.update!(status: :cancelled, cancelled_at: Time.current)
        FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                    event: 'invoice.cancelled', subject: @invoice)
      end
      redirect_to admin_supplier_invoice_path(@invoice)
    rescue ArgumentError => e
      financial_error(e, admin_supplier_invoice_path(@invoice))
    end

    def download_xml
      authorize @invoice, :download?
      return head :not_found unless @invoice.xml_document.attached?

      response.headers['Cache-Control'] = 'no-store'
      send_data @invoice.xml_document.download, filename: "cfdi-#{@invoice.id}.xml",
                                                type: 'application/xml', disposition: 'attachment'
    end

    private

    def new_invoice
      current_organization.supplier_invoices.new(created_by: current_user)
    end

    def set_invoice
      @invoice = policy_scope(current_organization.supplier_invoices).find(params[:id])
    end

    def invoice_params
      params.expect(supplier_invoice: %i[
                      supplier_id purchase_order_id currency_id series folio issued_on received_on
                      due_on subtotal discount tax_amount total exchange_rate notes
                      xml_document pdf_document
                    ])
    end

    def apply_attributes
      attrs = invoice_params.except(:xml_document, :pdf_document)
      supplier = current_organization.suppliers.not_deleted.find_by(id: attrs[:supplier_id] || @invoice.supplier_id)
      raise ArgumentError, 'Invalid supplier' unless supplier

      @invoice.assign_attributes(attrs.merge(supplier:))
      uploaded = invoice_params[:xml_document]
      if uploaded.present?
        raw = uploaded.read
        AccountsPayable::ImportCfdi.call(invoice: @invoice, xml: raw)
        @invoice.xml_document.attach(io: StringIO.new(raw), filename: uploaded.original_filename,
                                     content_type: 'application/xml')
      end
      @invoice.issued_on ||= Date.current
      @invoice.received_on ||= Date.current
      @invoice.due_on ||= @invoice.issued_on + supplier.credit_days.days
      @invoice.pdf_document.attach(invoice_params[:pdf_document]) if invoice_params[:pdf_document].present?
    end

    def load_catalogs
      @suppliers = current_organization.suppliers.available.order(:name)
      @currencies = Currency.active.order(:code)
      @orders = current_organization.purchase_orders.order(created_at: :desc).limit(200)
    end
  end
end
