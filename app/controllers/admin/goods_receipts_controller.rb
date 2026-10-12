# frozen_string_literal: true

module Admin
  class GoodsReceiptsController < ApplicationController
    include PurchasesAccess

    before_action :set_order, only: %i[index new create]

    def index
      authorize GoodsReceipt.new(organization: current_organization), :index?
      @receipts = @order.goods_receipts.includes(:received_by).order(created_at: :desc)
    end

    def show
      @receipt = policy_scope(current_organization.goods_receipts).find(params[:id])
      authorize @receipt
    end

    def new
      @receipt = @order.goods_receipts.new(organization: current_organization)
      authorize @receipt
    end

    def create
      authorize GoodsReceipt.new(organization: current_organization), :create?
      entries = params.fetch(:entries, {}).values.map(&:to_unsafe_h)
      @receipt = Purchases::Receive.call(
        order: @order, user: current_user, idempotency_key: params.require(:idempotency_key),
        entries:, notes: params[:notes]
      )
      redirect_to admin_goods_receipt_path(@receipt)
    rescue ActiveRecord::RecordInvalid, ArgumentError, ActiveRecord::RecordNotUnique => e
      reject_purchase(e, new_admin_purchase_order_goods_receipt_path(@order))
    end

    private

    def set_order
      @order = policy_scope(current_organization.purchase_orders).find(params[:purchase_order_id])
      authorize @order, :receive?
    end
  end
end
