# frozen_string_literal: true

# Compatibility bridge while legacy notes columns and consumers are migrated.
# The polymorphic note entry is authoritative for form display and future APIs.
module HasPolymorphicNotes
  extend ActiveSupport::Concern

  included do
    has_many :note_entries, class_name: 'Note', as: :notable, inverse_of: :notable, dependent: :destroy
    after_save :sync_general_note, if: :general_note_changed?
  end

  def note_body
    return @note_body if defined?(@note_body)
    return self[:notes] if has_attribute?(:notes) &&
                           (new_record? || will_save_change_to_attribute?('notes'))

    entry = if association(:note_entries).loaded?
              note_entries.find { |note| note.kind == 'general' }
            elsif persisted?
              note_entries.find_by(kind: 'general')
            end
    entry&.body || (has_attribute?(:notes) ? self[:notes] : nil)
  end

  def note_body=(value)
    @note_body = value.to_s.strip.presence
    @note_body_assigned = true
    self[:notes] = @note_body if has_attribute?(:notes)
  end

  def note_organization
    return organization if respond_to?(:organization) && organization.present?

    parents = %i[supplier contactable goods_receipt purchase_request purchase_return purchase_order]
    parents.each do |name|
      next unless respond_to?(name)

      parent = public_send(name)
      return parent if parent.is_a?(Organization)
      return parent.organization if parent&.respond_to?(:organization) && parent.organization.present?
    end
    nil
  end

  private

  def general_note_changed?
    @note_body_assigned || (has_attribute?(:notes) && saved_change_to_attribute?('notes'))
  end

  def sync_general_note
    content = @note_body_assigned ? @note_body : self[:notes].to_s.strip.presence
    entry = note_entries.find_by(kind: 'general')
    if content.present?
      if entry
        entry.update!(body: content, organization: note_organization) if entry.body != content ||
                                                                  entry.organization_id != note_organization&.id
      else
        note_entries.create!(kind: 'general', body: content, organization: note_organization)
      end
    else
      entry&.destroy!
    end
  ensure
    remove_instance_variable(:@note_body_assigned) if instance_variable_defined?(:@note_body_assigned)
    remove_instance_variable(:@note_body) if instance_variable_defined?(:@note_body)
  end
end
