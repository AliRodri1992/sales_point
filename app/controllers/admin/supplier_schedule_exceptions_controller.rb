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

    def bulk_update
      ids = Array(params[:exception_ids]).map(&:to_s).uniq
      return head :bad_request if ids.empty? || ids.size > 100 || ids.any? { |id| !id.match?(/\A[1-9]\d*\z/) }
      return head :bad_request unless params[:operation].in?(%w[archive restore])

      restoring = params[:operation] == 'restore'
      scope = @supplier.supplier_schedule_exceptions
      scope = restoring ? scope.with_deleted.where.not(deleted_at: nil) : scope
      records = scope.where(id: ids).order(:id).to_a
      return head :not_found unless records.size == ids.size

      @supplier.with_lock do
        records.each do |exception|
          exception.update!(deleted_at: restoring ? nil : Time.current)
        end
      end
      redirect_to admin_supplier_schedules_path(@supplier, archived: restoring ? '1' : nil),
                  notice: t('admin.supplier_schedule_exceptions.saved')
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_supplier_schedules_path(@supplier),
                  alert: error.record.errors.full_messages.to_sentence
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
