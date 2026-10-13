# frozen_string_literal: true

module AccountsPayable
  class ApplyPayment
    def self.call(payment:, allocations:, actor:)
      AccountPayable.transaction do
        payment.lock!
        raise ArgumentError, 'Payment already processed' unless payment.draft?

        entries = allocations.to_a.map do |item|
          [Integer(item.fetch(:account_payable_id)), BigDecimal(item.fetch(:amount).to_s)]
        end
        raise ArgumentError, 'Allocation list cannot be empty' if entries.empty?
        raise ArgumentError, 'Duplicate payable' unless entries.map(&:first).uniq.size == entries.size
        raise ArgumentError, 'Payment amount differs from allocations' unless entries.sum(&:last) == payment.amount

        payables = payment.organization.account_payables.where(id: entries.map(&:first)).order(:id).lock.index_by(&:id)
        raise ArgumentError, 'Unknown payable' unless payables.size == entries.size

        entries.each do |id, amount|
          payable = payables.fetch(id)
          raise ArgumentError, 'Invalid payment amount' unless amount.positive?
          raise ArgumentError, 'Different supplier or currency' unless payable.supplier_id == payment.supplier_id &&
                                                                       payable.supplier_invoice.currency_id == payment.currency_id
          raise ArgumentError, 'Invoice not posted' unless payable.supplier_invoice.posted?
          raise ArgumentError, 'Payment exceeds open balance' if amount > payable.balance

          payment.supplier_payment_allocations.create!(
            organization: payment.organization, account_payable: payable, amount:
          )
        end

        payment.update!(status: :posted, posted_at: Time.current)
        FinancialAuditEvent.record!(organization: payment.organization, actor:, event: 'payment.posted',
                                    subject: payment, details: { amount: payment.amount.to_s })
        payment
      end
    end
  end
end
