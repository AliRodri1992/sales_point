# frozen_string_literal: true

module Reports
  class PdfExporter
    def self.call(report:)
      renderer = ApplicationController.renderer
      html = renderer.render(
        template: 'reports/catalog', layout: 'reports/pdf',
        locals: { report:, organization_logo: organization_logo(report.organization), delta_logo: delta_logo }
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
    def self.delta_logo
      svg = Rails.root.join('app/assets/images/delta-pos-logo.svg').read
      "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
    end
    private_class_method :organization_logo, :delta_logo
  end
end
