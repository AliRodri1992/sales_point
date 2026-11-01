# frozen_string_literal: true

module Reports
  class ExportService
    FORMATS = { pdf: PdfExporter, xlsx: ExcelExporter }.freeze

    def self.call(report:, format:)
      exporter = FORMATS.fetch(format.to_sym)
      I18n.with_locale(report.locale) { exporter.call(report:) }
    end
  end
end
