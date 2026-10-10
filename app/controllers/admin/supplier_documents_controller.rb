# frozen_string_literal: true

module Admin
  class SupplierDocumentsController < ApplicationController
    before_action :authenticate_user!

    def destroy
      return head :forbidden unless current_organization

      supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize supplier, :update?
      attachment = supplier.documents.attachments.find(params[:document_id])
      attachment.purge
      redirect_to admin_supplier_path(supplier), notice: t('admin.supplier_details.deleted')
    end
  end
end
