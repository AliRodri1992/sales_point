# frozen_string_literal: true

module SupplierLifecycleActions
  def destroy
    authorize @supplier
    return archive_blocked unless @supplier.archivable?

    @supplier.update!(deleted_at: Time.current, status: :inactive)
    notify_supplier('destroyed')
    broadcast_suppliers_update
    redirect_to admin_suppliers_path, flash: { swal_message: t('admin.suppliers.destroyed') }
  end

  def restore
    @supplier = current_organization.suppliers.where.not(deleted_at: nil).find(params[:id])
    authorize @supplier, :restore?
    if @supplier.update(deleted_at: nil, status: :inactive)
      notify_supplier('updated')
      broadcast_suppliers_update
      redirect_to admin_suppliers_path(archived: '1'), notice: t('admin.suppliers.lifecycle.restored')
    else
      archive_restore_error
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to admin_suppliers_path(archived: '1'), alert: t('admin.suppliers.lifecycle.restore_conflict')
  end

  private

  def archive_blocked
    redirect_to admin_supplier_path(@supplier), alert: @supplier.errors.full_messages.to_sentence
  end

  def archive_restore_error
    redirect_to admin_suppliers_path(archived: '1'), alert: @supplier.errors.full_messages.to_sentence
  end
end
