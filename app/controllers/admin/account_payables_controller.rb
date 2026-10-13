# frozen_string_literal: true

module Admin
  class AccountPayablesController < ApplicationController
    include FinancialAccess

    def index
      authorize current_organization.account_payables.new, :index?
      @payables = policy_scope(current_organization.account_payables)
                  .includes(:supplier, supplier_invoice: :currency).order(due_on: :asc, id: :asc)
      @open = @payables.reject(&:settled?)
      @overdue = @open.select(&:overdue?)
    end

    def show
      @payable = policy_scope(current_organization.account_payables)
                 .includes(:supplier, :supplier_invoice, supplier_payment_allocations: :supplier_payment,
                           supplier_credit_allocations: :supplier_credit_note).find(params[:id])
      authorize @payable
    end
  end
end

