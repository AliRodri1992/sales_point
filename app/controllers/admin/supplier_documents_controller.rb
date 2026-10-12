# frozen_string_literal: true

module Admin
  class SupplierDocumentsController < ApplicationController
    include SupplierAuditTrail

    before_action :authenticate_user!

    def download
      supplier = authorized_supplier(:view_documents?)
      attachment = supplier.documents.attachments.find(params[:document_id])
      send_data attachment.blob.download, filename: attachment.blob.filename.to_s,
                                         type: attachment.blob.content_type, disposition: 'attachment'
    end

    def destroy
      return head :forbidden unless current_organization

      supplier = authorized_supplier(:manage_documents?)
      attachment = supplier.documents.attachments.find(params[:document_id])
      attachment.purge
      notify_document_deleted(supplier, attachment.id)
      redirect_to admin_supplier_path(supplier), notice: t('admin.supplier_details.deleted')
    end

    private

    def authorized_supplier(permission)
      supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize supplier, permission
      supplier
    end

    def notify_document_deleted(supplier, document_id)
      Suppliers::NotifyService.call(action: 'document_deleted', supplier:, user: current_user,
                                    subject: supplier, event_token: document_id)
    end
  end
end
