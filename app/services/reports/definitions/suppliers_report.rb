# frozen_string_literal: true

module Reports
  module Definitions
    class SuppliersReport < BaseReport
      def title
        I18n.t('reports.suppliers.title', locale:)
      end

      def columns(format: :pdf)
        keys = %i[code name classification status]
        keys += %i[rfc] if field_allowed?('suppliers.fiscal')
        keys += %i[email phone] if field_allowed?('suppliers.contacts')
        keys += %i[credit_days credit_limit] if format.to_sym == :xlsx && field_allowed?('suppliers.commercial')
        keys.map do |key|
          {
            label: I18n.t("reports.suppliers.columns.#{key}", locale:),
            value: ->(supplier) { column_value(supplier, key) }
          }
        end
      end

      # Keep the caller's sort order while preloading the contacts used by each row.
      def each_row(&block)
        scope.includes(contacts: :phones).each(&block)
      end

      private

      def field_allowed?(section)
        @field_access ||= {}
        @field_access.fetch(section) do
          @field_access[section] = user.present? &&
                                   organization.organization_memberships.active.exists?(user: user) &&
                                   (user.admin? || user.permission?("#{section}.view") ||
                                    user.permission?("#{section}.manage"))
        end
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
        contact = supplier.contacts.find do |item|
          item.primary? && item.active? && item.deleted_at.nil?
        end
        return '' unless contact

        contact.phones.find do |phone|
          phone.deleted_at.nil? && phone.kind == 'landline' && phone.primary?
        end&.number.to_s
      end
    end
  end
end
