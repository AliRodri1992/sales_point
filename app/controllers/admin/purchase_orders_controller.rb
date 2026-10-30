# frozen_string_literal: true

module Admin
  class PurchaseOrdersController < ApplicationController
    include PurchasesAccess
    include TableListingPagination

    before_action :set_order, only: %i[show edit update submit approve reject send_order cancel close]

    def index
      authorize new_record, :index?
      scope = policy_scope(current_organization.purchase_orders)
              .includes(:branch, :supplier).order(created_at: :desc)
      @orders = paginate_table_listing(scope, table_key: 'purchase_orders')
    end

    def show
      authorize @order
    end

    def new
      @order = order_from_quotation || new_record
      authorize @order
      3.times { @order.purchase_order_items.build } if @order.purchase_order_items.empty?
      load_purchase_catalogs
    end

    def edit
      authorize @order
      load_purchase_catalogs
    end

    def create
      @order = new_record
      authorize @order
      @order.assign_attributes(order_params)
      if @order.save
        redirect_to admin_purchase_order_path(@order)
      else
        load_purchase_catalogs
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @order
      if @order.update(order_params)
        redirect_to admin_purchase_order_path(@order)
      else
        load_purchase_catalogs
        render :edit, status: :unprocessable_content
      end
    end

    def submit = transition(:submit)
    def approve = transition(:approve)
    def reject = transition(:reject)
    def send_order = transition(:dispatch)
    def cancel = transition(:cancel)
    def close = transition(:close)

    private

    def new_record
      current_organization.purchase_orders.new(requested_by: current_user)
    end

    def order_from_quotation
      return if params[:quotation_id].blank?

      quotation = current_organization.purchase_quotations.find(params[:quotation_id])
      Purchases::BuildOrderFromQuotation.call(quotation:, requested_by: current_user)
    end

    def set_order
      @order = policy_scope(current_organization.purchase_orders).find(params[:id])
    end

    # Nested fields_for uses numeric-indexed hashes; preserve those attributes.
    def order_params
      # rubocop:disable-next Rails/StrongParametersExpect
      params.require(:purchase_order).permit(
        :branch_id, :supplier_id, :currency_id, :expected_on, :notes,
        :freight_amount, :insurance_amount, :exchange_rate,
        :purchase_request_id, :purchase_quotation_id,
        purchase_order_items_attributes: %i[
          id product_id supplier_product_id quantity units_per_package
          unit_price discount_percent nonrecoverable_tax
        ]
      )
    end

    def transition(action)
      authorize @order, :"#{action}?"
      Purchases::Workflow.call(order: @order, action:, user: current_user, notes: params[:notes])
      Purchases::Notify.call(record: @order, action: "order_#{action}", user: current_user)
      redirect_to admin_purchase_order_path(@order)
    rescue ArgumentError => e
      reject_purchase(e, admin_purchase_order_path(@order))
    end
  end
end
