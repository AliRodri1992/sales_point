# frozen_string_literal: true

module Admin
  class SupplierPaymentsController < ApplicationController
    include FinancialAccess

    before_action :set_payment, only: %i[show post_payment reverse]

    def index
      authorize current_organization.supplier_payments.new, :index?
      @payments = policy_scope(current_organization.supplier_payments)
                  .includes(:supplier, :currency).order(created_at: :desc)
    end

    def show
      authorize @payment
      @payables = current_organization.account_payables
                                      .where(supplier_id: @payment.supplier_id)
                                      .includes(supplier_invoice: :currency).order(:due_on).reject(&:settled?)
    end

    def new
      @payment = new_payment
      authorize @payment
      load_catalogs
    end

    def create
      @payment = new_payment
      authorize @payment
      @payment.assign_attributes(payment_params)
      if @payment.save
        FinancialAuditEvent.record!(organization: current_organization, actor: current_user,
                                    event: 'payment.created', subject: @payment)
        redirect_to admin_supplier_payment_path(@payment)
      else
        load_catalogs
        render :new, status: :unprocessable_content
      end
    end

    def post_payment
      authorize @payment, :post?
      allocations = params.require(:allocations).map do |row|
        row.permit(:account_payable_id, :amount).to_h.symbolize_keys
      end
      AccountsPayable::ApplyPayment.call(payment: @payment, allocations:, actor: current_user)
      redirect_to admin_supplier_payment_path(@payment)
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      financial_error(e, admin_supplier_payment_path(@payment))
    end

    def reverse
      authorize @payment, :reverse?
      AccountsPayable::ReversePayment.call(payment: @payment, actor: current_user)
      redirect_to admin_supplier_payment_path(@payment)
    rescue ArgumentError => e
      financial_error(e, admin_supplier_payment_path(@payment))
    end

    private

    def set_payment
      @payment = policy_scope(current_organization.supplier_payments).find(params[:id])
    end

    def new_payment
      current_organization.supplier_payments.new(created_by: current_user, paid_on: Date.current)
    end

    def load_catalogs
      @suppliers = current_organization.suppliers.available.order(:name)
      @currencies = Currency.active.order(:code)
    end

    def payment_params
      params.expect(supplier_payment: %i[
                      supplier_id currency_id supplier_bank_account_id paid_on amount reference notes
                    ])
    end
  end
end
