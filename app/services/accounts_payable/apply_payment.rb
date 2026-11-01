# frozen_string_literal: true

module AccountsPayable
  class ApplyPayment
    def self.call(payment:, allocations:, actor:)
      new(payment:, allocations:, actor:).call
    end

    def initialize(payment:, allocations:, actor:)
      @payment = payment
      @allocations = allocations
      @actor = actor
    end

    def call
      AccountPayable.transaction do
        @payment.lock!
        verify_draft!
        entries = parsed_entries
        payables = locked_payables(entries)
        entries.each { |id, amount| allocate!(payables.fetch(id), amount) }
        @payment.update!(status: :posted, posted_at: Time.current)
        audit_posting!
      end
      @payment
    end

    private

    def verify_draft!
      raise ArgumentError, 'Payment already processed' unless @payment.draft?
    end

    def parsed_entries
      entries = @allocations.to_a.map do |item|
        [Integer(item.fetch(:account_payable_id)), BigDecimal(item.fetch(:amount).to_s)]
      end
      raise ArgumentError, 'Allocation list cannot be empty' if entries.empty?
      raise ArgumentError, 'Duplicate payable' unless entries.map(&:first).uniq.size == entries.size
      raise ArgumentError, 'Payment amount differs from allocations' unless entries.sum(&:last) == @payment.amount

      entries
    end

    def locked_payables(entries)
      result = @payment.organization.account_payables.where(id: entries.map(&:first))
                       .order(:id).lock.index_by(&:id)
      raise ArgumentError, 'Unknown payable' unless result.size == entries.size

      result
    end

    def allocate!(payable, amount)
      raise ArgumentError, 'Invalid payment amount' unless amount.positive?
      raise ArgumentError, 'Different supplier or currency' unless same_supplier_and_currency?(payable)
      raise ArgumentError, 'Invoice not posted' unless payable.supplier_invoice.posted?
      raise ArgumentError, 'Payment exceeds open balance' if amount > payable.balance

      @payment.supplier_payment_allocations.create!(
        organization: @payment.organization, account_payable: payable, amount:
      )
    end

    def same_supplier_and_currency?(payable)
      payable.supplier_id == @payment.supplier_id &&
        payable.supplier_invoice.currency_id == @payment.currency_id
    end

    def audit_posting!
      FinancialAuditEvent.record!(organization: @payment.organization, actor: @actor,
                                  event: 'payment.posted', subject: @payment,
                                  details: { amount: @payment.amount.to_s })
    end
  end
end
