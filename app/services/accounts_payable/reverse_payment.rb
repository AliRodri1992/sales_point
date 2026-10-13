# frozen_string_literal: true

module AccountsPayable
  class ReversePayment
    def self.call(payment:, actor:)
      AccountPayable.transaction do
        payment.lock!
        raise ArgumentError, 'Only posted payments can be reversed' unless payment.posted?

        payment.supplier_payment_allocations.order(:account_payable_id).each do |allocation|
          allocation.account_payable.lock!
        end
        payment.update!(status: :reversed, reversed_at: Time.current)
        FinancialAuditEvent.record!(organization: payment.organization, actor:,
                                    event: 'payment.reversed', subject: payment)
        payment
      end
    end
  end
end
