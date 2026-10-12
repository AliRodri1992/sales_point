# frozen_string_literal: true

module Purchases
  class Workflow
    TRANSITIONS = {
      'draft' => { submit: 'pending_approval', cancel: 'cancelled' },
      'pending_approval' => { approve: 'approved', reject: 'rejected', cancel: 'cancelled' },
      'approved' => { dispatch: 'ordered', cancel: 'cancelled' },
      'ordered' => { cancel: 'cancelled' }
    }.freeze

    def self.call(order:, action:, user:, notes: nil)
      order.with_lock do
        next_status = TRANSITIONS.fetch(order.status, {})[action.to_sym]
        raise ArgumentError, 'Invalid order status transition' unless next_status
        raise ArgumentError, 'Purchase order needs items' if action.to_sym == :submit && order.purchase_order_items.empty?
        if action.to_sym.in?(%i[approve reject]) && order.requested_by_id == user.id
          raise ArgumentError, 'Requester cannot approve or reject own order'
        end
        raise ArgumentError, 'Already received stock cannot be cancelled' if action.to_sym == :cancel &&
                                                                           order.goods_receipts.exists?

        attributes = { status: next_status }
        attributes.merge!(approved_by: user, approved_at: Time.current) if action.to_sym == :approve
        attributes[:cancelled_at] = Time.current if action.to_sym == :cancel
        order.update!(attributes)
        if action.to_sym.in?(%i[approve reject])
          order.purchase_approvals.create!(
            organization: order.organization, decided_by: user, decision: next_status, notes:
          )
        end
        order
      end
    end

    def self.submit_request!(request)
      request.with_lock do
        raise ArgumentError, 'Request is not a draft' unless request.draft?
        raise ArgumentError, 'Request needs items' if request.purchase_request_items.empty?

        request.update!(status: :submitted, submitted_at: Time.current)
      end
    end

    def self.decide_request!(request, status:)
      request.with_lock do
        raise ArgumentError, 'Request must be submitted' unless request.submitted?
        raise ArgumentError, 'Unsupported request decision' unless status.in?(%w[approved rejected])

        request.update!(status:)
      end
    end
  end
end
