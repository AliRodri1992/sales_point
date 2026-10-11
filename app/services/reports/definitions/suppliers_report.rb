# frozen_string_literal: true

module Reports
  module Definitions
    class SuppliersReport < BaseReport
      def title
        I18n.t('reports.suppliers.title', locale:)
      end

      def columns(format: :pdf)
        keys = %i[code name rfc email phone classification status]
        keys += %i[credit_days credit_limit] if format.to_sym == :xlsx
        keys.map do |key|
          {
            label: I18n.t("reports.suppliers.columns.#{key}", locale:),
            value: ->(supplier) { column_value(supplier, key) }
          }
        end
      end

      private

      def column_value(supplier, key)
        case key
        when :status
          I18n.t("admin.suppliers.statuses.#{supplier.status}", locale:)
        when :classification
          return '' if supplier.classification.blank?

          I18n.t("admin.suppliers.index.advanced.options.#{supplier.classification}", locale:)
        else
          supplier.public_send(key).to_s
        end
      end
    end
  end
end
