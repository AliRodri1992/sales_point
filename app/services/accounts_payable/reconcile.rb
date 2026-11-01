# frozen_string_literal: true

module AccountsPayable
  class Reconcile
    def self.call(supplier:)
      payables = supplier.account_payables.includes(supplier_invoice: :currency)
                         .order(due_on: :asc).select { |entry| entry.supplier_invoice.posted? }
      payables.group_by { |entry| entry.supplier_invoice.currency.code }
              .transform_values { |items| reconcile_currency(items) }
    end

    def self.reconcile_currency(items)
      total = items.sum(&:amount)
      payments = items.sum(&:paid_amount)
      credits = items.sum(&:credited_amount)
      pending = total - payments - credits
      raise ArgumentError, 'Financial reconciliation has a negative balance' if pending.negative?

      { invoices: items.size, total:, payments:, credits:, pending:,
        overdue: items.select(&:overdue?).sum(&:balance) }
    end
  end
end
