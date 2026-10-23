# frozen_string_literal: true

module Admin
  class SupplierEventsController < ApplicationController
    include SupplierAuditTrail

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_event, only: %i[edit update destroy]

    def new
      @event = @supplier.supplier_events.new(starts_at: Time.zone.now.change(min: 0))
      load_branches
    end

    def edit
      load_branches
    end

    def create
      @event = @supplier.supplier_events.new(event_params)
      @event.created_by = current_user
      return redirect_success(:created) if @event.save

      load_branches
      render :new, status: :unprocessable_content
    end

    def update
      return redirect_success(:updated) if @event.update(event_params)

      load_branches
      render :edit, status: :unprocessable_content
    end

    def destroy
      @event.update!(deleted_at: Time.current)
      redirect_success(:deleted)
    end

    def restore
      @event = @supplier.supplier_events.where.not(deleted_at: nil).find(params[:id])
      return redirect_success(:restored) if @event.update(deleted_at: nil)

      redirect_to admin_supplier_path(@supplier, tab: 'schedules'),
                  alert: @event.errors.full_messages.to_sentence
    end

    private

    def set_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, :manage_schedules?
    end

    def set_event
      @event = @supplier.supplier_events.not_deleted.find(params[:id])
    end

    def load_branches
      @branches = current_organization.branches.not_deleted.order(:name)
    end

    def redirect_success(action)
      Suppliers::NotifyService.call(action: "event_#{action}", supplier: @supplier,
                                    user: current_user, subject: @event)
      redirect_to admin_supplier_path(@supplier, tab: 'schedules'),
                  flash: { swal_message: t("admin.supplier_calendar.messages.#{action}") }
    end

    def event_params
      params.expect(supplier_event: %i[title kind branch_id starts_at ends_at notes])
    end
  end
end
