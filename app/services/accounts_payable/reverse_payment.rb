# frozen_string_literal: true

module AccountsPayable
  class ReversePayment
    def self.call(payment:, actor:)
      AccountPayable.transaction do
        payment.lock!
        raise ArgumentError, 'Only posted payments can be reversed' unless payment.posted?

        payable_ids = payment.supplier_payment_allocations.order(:account_payable_id).pluck(:account_payable_id)
        AccountPayable.where(id: payable_ids).order(:id).lock.load
        payment.update!(status: :reversed, reversed_at: Time.current)
        FinancialAuditEvent.record!(organization: payment.organization, actor:,
                                    event: 'payment.reversed', subject: payment)
        payment
      end
    end
  end
end
