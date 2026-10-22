# frozen_string_literal: true

module Admin
  class AccountPayablesController < ApplicationController
    include FinancialAccess

    def index
      authorize current_organization.account_payables.new, :index?
      load_supplier_filter
      scope = scoped_payables
      @open = scope.with_positive_balance
      @open_count = @open.count
      @currency_balances = Suppliers::PayablesCurrencySummary.new(@open).call
      @total_payables = scope.count
      @pages = [(@total_payables.to_f / 20).ceil, 1].max
      @page = params[:page].to_i.clamp(1, @pages)
      @payables = scope.includes(:supplier, supplier_invoice: :currency)
                       .order(due_on: :asc, id: :asc).limit(20).offset((@page - 1) * 20)
    end

    def load_supplier_filter
      return if params[:supplier_id].blank?

      @supplier = current_organization.suppliers.not_deleted.find(params[:supplier_id])
    end

    def scoped_payables
      scope = policy_scope(current_organization.account_payables)
      @supplier ? scope.where(supplier_id: @supplier.id) : scope
    end

    def show
      @payable = policy_scope(current_organization.account_payables)
                 .includes(:supplier, :supplier_invoice)
                 .includes(supplier_payment_allocations: :supplier_payment)
                 .includes(supplier_credit_allocations: :supplier_credit_note).find(params[:id])
      authorize @payable
    end
  end
end
