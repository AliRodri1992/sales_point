# frozen_string_literal: true

module Reports
  module Definitions
    class SuppliersReport < BaseReport
      def title
        I18n.t('reports.suppliers.title', locale:)
      end

      def columns(format: :pdf)
        keys = %i[code name classification status]
        keys += %i[rfc] if field_allowed?(:view_fiscal?)
        keys += %i[email phone] if field_allowed?(:view_contacts?)
        keys += %i[credit_days credit_limit] if format.to_sym == :xlsx && field_allowed?(:view_commercial?)
        keys.map do |key|
          {
            label: I18n.t("reports.suppliers.columns.#{key}", locale:),
            value: ->(supplier) { column_value(supplier, key) }
          }
        end
      end

      private

      def field_allowed?(permission)
        policy = SupplierPolicy.new(user, scope.klass.new(organization: organization))
        policy.public_send(permission)
      end

      def column_value(supplier, key)
        return primary_office_number(supplier) if key == :phone

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

      def primary_office_number(supplier)
        return '' unless SupplierPolicy.new(user, supplier).view_contacts?

        contact = supplier.contacts.not_deleted.find_by(primary: true, active: true)
        return '' unless contact

        contact.phones.active.find_by(kind: 'landline', primary: true)&.number.to_s
      end
    end
  end
end
