# frozen_string_literal: true

module Reports
  module Definitions
    class SuppliersReport < BaseReport
      def title
        I18n.t('reports.suppliers.title', locale:)
      end

      def columns(format: :pdf)
        @field_access = {}
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

      EXPORT_BATCH_SIZE = 200

      # Read related contacts/phones per batch, preserving the caller's sort.
      # Avoid materializing entire multi-thousand-row exports in Ruby memory.
      def each_row(&)
        records = scope.preload(contacts: :phones)
        return records.each(&) if records.limit_value

        each_page(records, &)
      end

      private

      def each_page(records, &)
        records = records.order(:id) if records.order_values.empty?
        offset = records.offset_value.to_i

        loop do
          page = records.limit(EXPORT_BATCH_SIZE).offset(offset).to_a
          break if page.empty?

          page.each(&)
          offset += EXPORT_BATCH_SIZE
        end
      end

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
        contact = supplier.contacts.to_a.find { |item| primary_active_contact?(item) }
        return '' unless contact

        contact.phones.to_a.find { |phone| primary_office_phone?(phone) }&.number.to_s
      end

      def primary_active_contact?(contact)
        contact.primary? && contact.active? && contact.deleted_at.nil?
      end

      def primary_office_phone?(phone)
        phone.deleted_at.nil? && phone.kind == 'landline' && phone.primary?
      end
    end
  end
end
