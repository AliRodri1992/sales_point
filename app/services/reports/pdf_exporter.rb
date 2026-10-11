# frozen_string_literal: true

module Reports
  class PdfExporter
    def self.call(report:)
      renderer = ApplicationController.renderer
      html = renderer.render(template: 'reports/catalog', layout: 'reports/pdf', locals: { report: })
      WickedPdf.new.pdf_from_string(
        html, orientation: 'Landscape', page_size: 'A4',
              margin: { top: 12, bottom: 15, left: 10, right: 10 }
      )
    end
  end
end
