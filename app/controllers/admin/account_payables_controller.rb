# frozen_string_literal: true

module Admin
  class AccountPayablesController < ApplicationController
    include FinancialAccess

    def index
      authorize current_organization.account_payables.new, :index?
      load_supplier_filter
      @payables = scoped_payables.includes(:supplier, supplier_invoice: :currency).order(due_on: :asc, id: :asc)
      @open = open_payables(@payables)
      @currency_balances = summarize_by_currency(@open)
    end

    def load_supplier_filter
      return if params[:supplier_id].blank?

      @supplier = current_organization.suppliers.not_deleted.find(params[:supplier_id])
    end

    def scoped_payables
      scope = policy_scope(current_organization.account_payables)
      @supplier ? scope.where(supplier_id: @supplier.id) : scope
    end

    def open_payables(payables)
      payables.select { |payable| payable.supplier_invoice.posted? && payable.balance.positive? }
    end

    def summarize_by_currency(payables)
      payables.group_by { |payable| payable.supplier_invoice.currency.code }
              .transform_values do |entries|
        { open: entries.sum(&:balance), overdue: entries.select(&:overdue?).sum(&:balance) }
      end
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
