# frozen_string_literal: true

module Reports
  class PdfExporter
    def self.call(report:)
      renderer = ApplicationController.renderer
      html = renderer.render(
        template: 'reports/catalog', layout: 'reports/pdf',
        locals: { report:, organization_logo: organization_logo(report.organization) }
      )
      WickedPdf.new.pdf_from_string(
        html, orientation: 'Landscape', page_size: 'A4',
              margin: { top: 12, bottom: 15, left: 10, right: 10 }
      )
    end

    def self.organization_logo(organization)
      return unless organization.logo.attached?

      blob = organization.logo.blob
      return unless %w[image/png image/jpeg].include?(blob.content_type)

      "data:#{blob.content_type};base64,#{Base64.strict_encode64(blob.download)}"
    end
    private_class_method :organization_logo
  end
end
