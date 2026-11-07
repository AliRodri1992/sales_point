# frozen_string_literal: true

module Products
  class DecidePriceChange
    class StalePrice < StandardError; end

    def initialize(event:, actor:, decision:)
      @event = event
      @actor = actor
      @decision = decision
    end

    def call
      raise Pundit::NotAuthorizedError unless @actor.admin? && member_of_organization?
      raise ArgumentError unless %w[approved rejected].include?(@decision)

      @event.with_lock do
        raise StalePrice unless @event.pending?

        product = @event.product
        raise StalePrice unless product

        product.with_lock { apply_decision }
      end
    end

    private

    def member_of_organization?
      @actor.organization_memberships.accessible.exists?(organization_id: @event.organization_id)
    end

    def apply_decision
      raise StalePrice if @decision == 'approved' && @event.product.price != @event.previous_price

      @event.product.update!(price: @event.new_price) if @decision == 'approved'
      @event.update!(status: @decision, approved_by: @actor, approved_at: Time.current)
    end
  end
end
