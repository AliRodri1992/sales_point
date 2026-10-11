# frozen_string_literal: true

module Admin
  module SuppliersExporting
    def export
      authorize Supplier, :index?
      return head :bad_request unless params[:supplier_id].to_s.match?(/\A[1-9]\d*\z/)

      supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize supplier, :show?
      scope = current_organization.suppliers.where(id: supplier.id)
      format = params[:file_format].to_s
      return head :bad_request unless %w[pdf xlsx].include?(format)

      report = supplier_export_report(scope)
      send_supplier_export(report, format)
    end

    private

    def supplier_export_report(scope)
      Reports::Definitions::SuppliersReport.new(
        scope:, organization: current_organization, user: current_user, locale: I18n.locale
      )
    end

    def send_supplier_export(report, format)
      mime = if format == 'pdf'
               'application/pdf'
             else
               'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
             end
      contents = Reports::ExportService.call(report:, format:)
      send_data contents, filename: "#{report.filename}.#{format}", type: mime, disposition: 'attachment'
    end
  end
end
