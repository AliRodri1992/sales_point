# frozen_string_literal: true

module Admin
  class SupplierScheduleExceptionsController < ApplicationController
    include SupplierAuditTrail

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier

    def create
      exception = @supplier.supplier_schedule_exceptions.new(exception_params)
      exception.created_by = current_user
      if exception.save
        redirect_to admin_supplier_schedules_path(@supplier),
                    notice: t('admin.supplier_schedule_exceptions.saved')
      else
        redirect_to admin_supplier_schedules_path(@supplier), alert: exception.errors.full_messages.to_sentence
      end
    end

    def destroy
      exception = @supplier.supplier_schedule_exceptions.find(params[:id])
      exception.destroy!
      redirect_to admin_supplier_schedules_path(@supplier),
                  notice: t('admin.supplier_schedule_exceptions.deleted')
    end

    private

    def set_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, :manage_schedules?
    end

    def exception_params
      params.expect(supplier_schedule_exception: %i[starts_on ends_on reason branch_id notes])
    end
  end
end
