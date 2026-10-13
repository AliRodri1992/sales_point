# frozen_string_literal: true

module Admin
  class PurchaseQuotationsController < ApplicationController
    include PurchasesAccess

    before_action :set_quotation, only: %i[show edit update submit accept reject]

    def index
      authorize new_record, :index?
      @quotations = policy_scope(current_organization.purchase_quotations).includes(:supplier).order(created_at: :desc)
    end

    def show
      authorize @quotation
    end

    def new
      @quotation = new_record
      authorize @quotation
      3.times { @quotation.purchase_quotation_items.build }
      load_purchase_catalogs
    end

    def edit
      authorize @quotation
      raise ActiveRecord::RecordNotFound unless @quotation.draft?

      load_purchase_catalogs
    end

    def create
      @quotation = new_record
      authorize @quotation
      @quotation.assign_attributes(quotation_params)
      if @quotation.save
        redirect_to admin_purchase_quotation_path(@quotation)
      else
        load_purchase_catalogs
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @quotation
      raise ActiveRecord::RecordNotFound unless @quotation.draft?

      if @quotation.update(quotation_params)
        redirect_to admin_purchase_quotation_path(@quotation)
      else
        load_purchase_catalogs
        render :edit, status: :unprocessable_content
      end
    end

    def submit
      change_status!(:submitted, from: :draft, permission: :update?)
    end

    def accept
      raise ArgumentError, 'Quotation has expired' unless @quotation.valid_offer?

      change_status!(:accepted, from: :submitted, permission: :accept?)
    rescue ArgumentError => e
      reject_purchase(e, admin_purchase_quotation_path(@quotation))
    end

    def reject
      change_status!(:rejected, from: :submitted, permission: :reject?)
    end

    private

    def new_record
      current_organization.purchase_quotations.new
    end

    def set_quotation
      @quotation = policy_scope(current_organization.purchase_quotations).find(params[:id])
    end

    # Nested fields_for uses numeric-indexed hashes; preserve those attributes.
    # rubocop:disable Rails/StrongParametersExpect
    def quotation_params
      params.require(:purchase_quotation).permit(
        :supplier_id, :purchase_request_id, :currency_id, :valid_until, :notes,
        purchase_quotation_items_attributes: %i[
          id product_id supplier_product_id quantity units_per_package
          unit_price discount_percent lead_time_days
        ]
      )
    end
    # rubocop:enable Rails/StrongParametersExpect

    def change_status!(status, from:, permission:)
      authorize @quotation, permission
      @quotation.with_lock do
        raise ArgumentError, 'Invalid quotation status transition' unless @quotation.status == from.to_s

        @quotation.update!(status:)
      end
      redirect_to admin_purchase_quotation_path(@quotation)
    rescue ArgumentError => e
      reject_purchase(e, admin_purchase_quotation_path(@quotation))
    end
  end
end
