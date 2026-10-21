# frozen_string_literal: true

module Suppliers
  class FinancialSummary
    attr_reader :recent, :pending_count, :next_due, :has_payable_records

    def initialize(supplier)
      @supplier = supplier
    end

    def call
      @pending_count = outstanding.count
      @has_payable_records = @supplier.account_payables.exists?
      @next_due = outstanding.where(due_on: Date.current..).minimum(:due_on)
      @balances = grouped_balances(outstanding)
      @overdue = grouped_balances(outstanding.where(due_on: ...Date.current))
      @recent = outstanding.joins(:supplier_invoice)
                           .includes(supplier_invoice: :currency,
                                     supplier_payment_allocations: :supplier_payment,
                                     supplier_credit_allocations: :supplier_credit_note)
                           .order('supplier_invoices.issued_on DESC, account_payables.id DESC').limit(5)
      self
    end

    def balance_labels(&)
      labels(@balances, &)
    end

    def overdue_labels(&)
      labels(@overdue, &)
    end

    private

    def outstanding
      @outstanding ||= @supplier.account_payables.with_positive_balance
    end

    def grouped_balances(scope)
      scope.joins(supplier_invoice: :currency)
           .group('currencies.code')
           .sum(Arel.sql(AccountPayable.balance_sql))
    end

    def labels(groups)
      values = groups.sort.map { |code, amount| "#{yield(amount)} #{code}" }
      return values if values.any?

      ["#{yield(0)} #{@supplier.currency.code}"]
    end
  end
end
