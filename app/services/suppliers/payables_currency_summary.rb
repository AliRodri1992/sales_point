# frozen_string_literal: true

module Suppliers
  class PayablesCurrencySummary
    def initialize(scope)
      @scope = scope
    end

    def call
      @scope.joins(supplier_invoice: :currency)
            .group('currencies.code').pluck(
              'currencies.code',
              Arel.sql("SUM(#{AccountPayable.balance_sql})"),
              Arel.sql("SUM(CASE WHEN account_payables.due_on < CURRENT_DATE THEN " \
                       "#{AccountPayable.balance_sql} ELSE 0 END)")
            ).to_h do |code, total, overdue|
        [code, { open: total, overdue: }]
      end
    end
  end
end
