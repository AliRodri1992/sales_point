# frozen_string_literal: true

module AccountsPayable
  class Reconcile
    def self.call(supplier:)
      open_items = supplier.account_payables.includes(supplier_invoice: :currency)
                           .order(due_on: :asc).filter { |payable| payable.supplier_invoice.posted? }
      per_currency = open_items.group_by { |payable| payable.supplier_invoice.currency.code }
      per_currency.transform_values do |items|
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
end
