# frozen_string_literal: true

module AccountsPayable
  class ApplyCredit
    def self.call(credit_note:, account_payable:, amount:, actor:)
      AccountPayable.transaction do
        credit_note.lock!
        account_payable.lock!
        amount = BigDecimal(amount.to_s)
        raise ArgumentError, 'Credit must be posted' unless credit_note.posted?
        raise ArgumentError, 'Invoice must be posted' unless account_payable.supplier_invoice.posted?
        raise ArgumentError, 'Different organization or supplier' unless credit_note.organization_id == account_payable.organization_id &&
              credit_note.supplier_id == account_payable.supplier_id
        raise ArgumentError, 'Different currency' unless credit_note.currency_id == account_payable.supplier_invoice.currency_id
        raise ArgumentError, 'Invalid credit amount' unless amount.positive?
        raise ArgumentError, 'Insufficient available credit' if amount > credit_note.available_amount
        raise ArgumentError, 'Credit exceeds open balance' if amount > account_payable.balance

        entry = credit_note.supplier_credit_allocations.create!(
          organization: credit_note.organization, account_payable:, amount:
        )
        FinancialAuditEvent.record!(organization: credit_note.organization, actor:,
                                    event: 'credit.applied', subject: credit_note,
                                    details: { payable_id: account_payable.id, amount: amount.to_s })
        entry
      end
    end
  end
end

