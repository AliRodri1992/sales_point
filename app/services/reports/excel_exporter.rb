# frozen_string_literal: true

module Reports
  class ExcelExporter
    def self.call(report:)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: report.title.to_s.slice(0, 31)) do |sheet|
        header = sheet.styles.add_style(bg_color: '047857', fg_color: 'FFFFFF', b: true)
        sheet.add_row(report.columns.map { |column| column.fetch(:label) }, style: header)
        report.each_row do |record|
          values = report.columns.map { |column| column.fetch(:value).call(record).to_s }
          sheet.add_row(values.map { |value| safe_cell(value) }, types: Array.new(values.length, :string))
        end
        sheet.auto_filter.range = "A1:#{Axlsx::col_ref(report.columns.length - 1)}#{sheet.rows.length}" if sheet.rows.length > 1
      end
      package.to_stream.read
    end

    def self.safe_cell(value)
      value.match?(/\A\s*[=+@\-\t\r]/) ? "'#{value}" : value
    end
    private_class_method :safe_cell
  end
end
