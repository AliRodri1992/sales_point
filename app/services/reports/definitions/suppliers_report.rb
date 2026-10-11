# frozen_string_literal: true

module Reports
  module Definitions
    class SuppliersReport < BaseReport
      def title
        I18n.t('reports.suppliers.title', locale:)
      end

      def columns
        %i[code name rfc email status].map do |key|
          { label: I18n.t("reports.suppliers.columns.#{key}", locale:), value: ->(supplier) { supplier.public_send(key).to_s } }
        end
      end
    end
  end
end
