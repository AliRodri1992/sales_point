# frozen_string_literal: true

module Admin
  class PurchaseRequestsController < ApplicationController
    include PurchasesAccess

    before_action :set_request, only: %i[show edit update submit approve reject cancel]

    def index
      authorize new_record, :index?
      @requests = policy_scope(current_organization.purchase_requests).includes(:branch).order(created_at: :desc)
    end

    def show
      authorize @request
    end

    def new
      @request = new_record
      authorize @request
      3.times { @request.purchase_request_items.build }
      load_purchase_catalogs
    end

    def edit
      authorize @request
      load_purchase_catalogs
    end

    def create
      @request = new_record
      authorize @request
      @request.assign_attributes(request_params)
      if @request.save
        redirect_to admin_purchase_request_path(@request)
      else
        load_purchase_catalogs
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @request
      if @request.update(request_params)
        redirect_to admin_purchase_request_path(@request)
      else
        load_purchase_catalogs
        render :edit, status: :unprocessable_content
      end
    end

    def submit
      transition(:submit)
    end

    def approve
      transition(:approve)
    end

    def reject
      transition(:reject)
    end

    def cancel
      transition(:cancel)
    end

    private

    def new_record
      current_organization.purchase_requests.new(requested_by: current_user)
    end

    def set_request
      @request = policy_scope(current_organization.purchase_requests).find(params[:id])
    end

    # Nested fields_for uses numeric-indexed hashes; preserve those attributes.
    def request_params
      # rubocop:disable-next Rails/StrongParametersExpect
      params.require(:purchase_request).permit(
        :branch_id, :needed_on, :notes,
        purchase_request_items_attributes: %i[id product_id quantity notes]
      )
    end

    def transition(action)
      authorize @request, action == :submit ? :submit? : :"#{action}?"
      if action == :submit
        Purchases::Workflow.submit_request!(@request)
      elsif action == :cancel
        raise ArgumentError, 'Only draft requests may be cancelled' unless @request.draft?

        @request.update!(status: :cancelled)
      else
        decision = action == :approve ? 'approved' : 'rejected'
        Purchases::Workflow.decide_request!(@request, status: decision, user: current_user)
      end
      Purchases::Notify.call(record: @request, action: "request_#{action}", user: current_user)
      redirect_to admin_purchase_request_path(@request)
    rescue ArgumentError => e
      reject_purchase(e, admin_purchase_request_path(@request))
    end
  end
end
