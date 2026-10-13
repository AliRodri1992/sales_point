# frozen_string_literal: true

module Admin
  class PurchaseReturnsController < ApplicationController
    include PurchasesAccess

    def index
      authorize PurchaseReturn.new(organization: current_organization), :index?
      @returns = policy_scope(current_organization.purchase_returns)
                 .includes(goods_receipt: :purchase_order).order(created_at: :desc)
    end

    def show
      @return = policy_scope(current_organization.purchase_returns).find(params[:id])
      authorize @return
    end

    def new
      @receipt = policy_scope(current_organization.goods_receipts).find(params[:goods_receipt_id])
      @return = PurchaseReturn.new(organization: current_organization, goods_receipt: @receipt,
                                   requested_by: current_user)
      authorize @return
    end

    def create
      @receipt = policy_scope(current_organization.goods_receipts).find(params[:goods_receipt_id])
      @return = PurchaseReturn.new(organization: current_organization, goods_receipt: @receipt,
                                   requested_by: current_user)
      authorize @return
      @return.assign_attributes(return_params)
      if @return.save
        redirect_to admin_purchase_return_path(@return)
      else
        render :new, status: :unprocessable_content
      end
    end

    def process_return
      @return = policy_scope(current_organization.purchase_returns).find(params[:id])
      authorize @return, :process?
      Purchases::ProcessReturn.call(purchase_return: @return, user: current_user)
      Purchases::Notify.call(record: @return, action: 'return_processed', user: current_user)
      redirect_to admin_purchase_return_path(@return)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      reject_purchase(e, admin_purchase_return_path(@return))
    end

    private

    # Nested fields_for uses numeric-indexed hashes; preserve those attributes.
    def return_params
      # rubocop:disable-next Rails/StrongParametersExpect
      params.require(:purchase_return).permit(
        :reason, :notes,
        purchase_return_items_attributes: %i[goods_receipt_item_id quantity notes]
      )
    end
  end
end
