# frozen_string_literal: true

module Admin
  class SupplierCreditNotesController < ApplicationController
    include FinancialAccess

    before_action :set_credit, only: %i[show post_credit apply cancel download_xml]

    def index
      authorize current_organization.supplier_credit_notes.new, :index?
      @credits = policy_scope(current_organization.supplier_credit_notes)
                 .includes(:supplier, :currency).order(created_at: :desc)
    end

    def show
      authorize @credit
      @payables = current_organization.account_payables
                                      .where(supplier_id: @credit.supplier_id)
                                      .includes(supplier_invoice: :currency).order(:due_on).reject(&:settled?)
    end

    def new
      @credit = new_credit
      authorize @credit
      load_catalogs
    end

    def create
      @credit = new_credit
      authorize @credit
      @credit.assign_attributes(credit_params.except(:xml_document))
      attach_credit_xml!
      save_credit
    rescue ArgumentError => e
      @credit.errors.add(:base, e.message)
      load_catalogs
      render :new, status: :unprocessable_content
    end

    def download_xml
      authorize @credit, :show?
      send_financial_attachment(@credit.xml_document, "credit-#{@credit.id}.xml", 'application/xml')
    end

    def post_credit
      authorize @credit, :post?
      @credit.with_lock do
        raise ArgumentError, 'Credit already processed' unless @credit.draft?

        @credit.update!(status: :posted)
        FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                    event: 'credit.posted', subject: @credit)
      end
      redirect_to admin_supplier_credit_note_path(@credit)
    rescue ArgumentError => e
      financial_error(e, admin_supplier_credit_note_path(@credit))
    end

    def apply
      authorize @credit, :apply?
      payable = current_organization.account_payables.find(params[:account_payable_id])
      AccountsPayable::ApplyCredit.call(credit_note: @credit, account_payable: payable,
                                        amount: params[:amount], actor: current_user)
      redirect_to admin_supplier_credit_note_path(@credit)
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      financial_error(e, admin_supplier_credit_note_path(@credit))
    end

    def cancel
      authorize @credit, :cancel?
      @credit.with_lock do
        if @credit.supplier_credit_allocations.exists?
          raise ArgumentError,
                'Credit cannot be cancelled after allocation'
        end

        @credit.update!(status: :cancelled)
        FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                    event: 'credit.cancelled', subject: @credit)
      end
      redirect_to admin_supplier_credit_note_path(@credit)
    rescue ArgumentError => e
      financial_error(e, admin_supplier_credit_note_path(@credit))
    end

    private

    def new_credit
      current_organization.supplier_credit_notes.new(created_by: current_user, issued_on: Date.current)
    end

    def set_credit
      @credit = policy_scope(current_organization.supplier_credit_notes).find(params[:id])
    end

    def credit_params
      params.expect(supplier_credit_note: %i[
                      supplier_id currency_id supplier_invoice_id purchase_return_id
                      uuid folio issued_on total notes xml_document
                    ])
    end

    def attach_credit_xml!
      upload = credit_params[:xml_document]
      return if upload.blank?

      raw = upload.read
      data = AccountsPayable::CfdiParser.call(xml: raw, expected_type: 'E')
      validate_cfdi_supplier!(data)
      @credit.assign_attributes(uuid: data.fetch(:uuid), total: data.fetch(:total),
                                issued_on: data.fetch(:issued_on))
      @credit.xml_document.attach(
        io: StringIO.new(raw), filename: upload.original_filename, content_type: 'application/xml'
      )
    end

    def save_credit
      if @credit.save
        FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                    event: 'credit.created', subject: @credit)
        redirect_to admin_supplier_credit_note_path(@credit)
      else
        load_catalogs
        render :new, status: :unprocessable_content
      end
    end

    def validate_cfdi_supplier!(data)
      supplier = current_organization.suppliers.find_by(id: @credit.supplier_id)
      raise ArgumentError, 'Invalid supplier' unless supplier
      raise ArgumentError, 'Issuer RFC does not match supplier' unless data[:issuer_rfc] == supplier.rfc
      valid_receiver = data[:receiver_rfc] == current_organization.tax_id
      raise ArgumentError, 'Receiver RFC does not match organization' unless valid_receiver

      return if @credit.currency_id == Currency.find_by(code: data[:currency_code])&.id

      raise ArgumentError, 'Currency does not match XML'
    end

    def load_catalogs
      @suppliers = current_organization.suppliers.available.order(:name)
      @currencies = Currency.active.order(:code)
      @invoices = current_organization.supplier_invoices.posted.order(created_at: :desc).limit(200)
      @returns = current_organization.purchase_returns.processed.order(created_at: :desc).limit(200)
    end
  end
end
