# frozen_string_literal: true

module AccountsPayable
  class ApplyCredit
    def self.call(credit_note:, account_payable:, amount:, actor:)
      new(credit_note:, account_payable:, amount:, actor:).call
    end

    def initialize(credit_note:, account_payable:, amount:, actor:)
      @credit = credit_note
      @payable = account_payable
      @amount = BigDecimal(amount.to_s)
      @actor = actor
    end

    def call
      AccountPayable.transaction do
        @credit.lock!
        @payable.lock!
        validate_allocation!
        entry = @credit.supplier_credit_allocations.create!(
          organization: @credit.organization, account_payable: @payable, amount: @amount
        )
        audit_allocation!
        entry
      end
    end

    private

    def validate_allocation!
      raise ArgumentError, 'Credit must be posted' unless @credit.posted?
      raise ArgumentError, 'Invoice must be posted' unless @payable.supplier_invoice.posted?
      raise ArgumentError, 'Different organization or supplier' unless same_supplier?
      raise ArgumentError, 'Different currency' unless same_currency?
      raise ArgumentError, 'Invalid credit amount' unless @amount.positive?
      raise ArgumentError, 'Insufficient available credit' if @amount > @credit.available_amount
      raise ArgumentError, 'Credit exceeds open balance' if @amount > @payable.balance
    end

    def same_supplier?
      @credit.organization_id == @payable.organization_id &&
        @credit.supplier_id == @payable.supplier_id
    end

    def same_currency?
      @credit.currency_id == @payable.supplier_invoice.currency_id
    end

    def audit_allocation!
      FinancialAuditEvent.record!(organization: @credit.organization, actor: @actor,
                                  event: 'credit.applied', subject: @credit,
                                  details: { payable_id: @payable.id, amount: @amount.to_s })
    end
  end
end
