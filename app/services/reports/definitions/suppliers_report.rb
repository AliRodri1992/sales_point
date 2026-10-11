# frozen_string_literal: true

module Reports
  module Definitions
    class SuppliersReport < BaseReport
      def title
        I18n.t('reports.suppliers.title', locale:)
      end

      def columns
        %i[code name rfc email status].map do |key|
          {
            label: I18n.t("reports.suppliers.columns.#{key}", locale:),
            value: ->(supplier) { column_value(supplier, key) }
          }
        end
      end

      private

      def column_value(supplier, key)
        return supplier.public_send(key).to_s unless key == :status

        I18n.t("admin.suppliers.statuses.#{supplier.status}", locale:)
      end
    end
  end
end
