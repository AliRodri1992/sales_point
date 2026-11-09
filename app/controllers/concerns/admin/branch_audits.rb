# frozen_string_literal: true

module Admin
  # Read-only audit feed for branch attributes and polymorphic contact details.
  module BranchAudits
    AUDITED_FIELDS = {
      'Branch' => %w[name code contact_email deleted_at],
      'Address' => %w[
        street exterior_number interior_number neighborhood city state postal_code country_id reference_notes deleted_at
      ],
      'Phone' => %w[number kind primary whatsapp_enabled deleted_at],
      'Note' => %w[body deleted_at]
    }.freeze
    AUDIT_YAML_CLASSES = [Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone].freeze

    private

    def load_branch_change_events
      events = branch_audit_sources.flat_map { |type, ids| branch_audit_versions(type, ids) }
      @branch_change_events = events.filter_map { |event| branch_audit_entry(event) }
                                    .sort_by { |entry| entry[:event].created_at }.last(20).reverse
      load_branch_change_actors
      load_branch_change_countries
    end

    def branch_audit_sources
      {
        'Branch' => [@branch.id],
        'Address' => Address.with_deleted.where(addressable_type: 'Branch', addressable_id: @branch.id).pluck(:id),
        'Phone' => Phone.with_deleted.where(phoneable_type: 'Branch', phoneable_id: @branch.id).pluck(:id),
        'Note' => Note.with_deleted.where(notable_type: 'Branch', notable_id: @branch.id).pluck(:id)
      }
    end

    def branch_audit_versions(type, ids)
      return [] if ids.empty?

      PaperTrail::Version.where(item_type: type, item_id: ids)
                         .order(created_at: :desc).limit(20).to_a
    end

    def branch_audit_entry(event)
      fields = branch_audit_changes(event).stringify_keys.slice(*AUDITED_FIELDS.fetch(event.item_type))
      { event:, fields: } if fields.present?
    end

    def branch_audit_changes(event)
      changes = event.changeset.to_h
      return changes if changes.present? || event.object_changes.blank?

      parsed = YAML.safe_load(event.object_changes, permitted_classes: AUDIT_YAML_CLASSES, aliases: true)
      parsed.is_a?(Hash) ? parsed : {}
    rescue Psych::Exception, TypeError
      {}
    end

    def load_branch_change_countries
      ids = @branch_change_events.flat_map do |entry|
        entry[:event].item_type == 'Address' ? entry[:fields].fetch('country_id', []) : []
      end.compact
      @branch_change_countries = Country.with_deleted.where(id: ids).index_by(&:id)
    end

    def load_branch_change_actors
      ids = @branch_change_events.filter_map { |entry| Integer(entry[:event].whodunnit, exception: false) }
      @branch_change_actors = User.where(id: ids).index_by(&:id)
    end
  end
end
