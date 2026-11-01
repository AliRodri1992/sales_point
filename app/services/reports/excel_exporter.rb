# frozen_string_literal: true

module Reports
  class ExcelExporter
    def self.call(report:)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: report.title.to_s.slice(0, 31)) do |sheet|
        populate_sheet(sheet, report)
      end
      package.to_stream.read
    end

    def self.populate_sheet(sheet, report)
      columns = report.columns(format: :xlsx)
      header = sheet.styles.add_style(bg_color: '047857', fg_color: 'FFFFFF', b: true)
      sheet.add_row(columns.map { |column| column.fetch(:label) }, style: header)
      report.each_row { |record| append_record(sheet, columns, record) }
      return unless sheet.rows.length > 1

      last_column = Axlsx.col_ref(columns.length - 1)
      sheet.auto_filter.range = "A1:#{last_column}#{sheet.rows.length}"
    end

    def self.append_record(sheet, columns, record)
      values = columns.map { |column| safe_cell(column.fetch(:value).call(record).to_s) }
      sheet.add_row(values, types: Array.new(values.length, :string))
    end

    def self.safe_cell(value)
      value.match?(/\A\s*[=+@\-\t\r]/) ? "'#{value}" : value
    end

    private_class_method :populate_sheet, :append_record, :safe_cell
  end
end
