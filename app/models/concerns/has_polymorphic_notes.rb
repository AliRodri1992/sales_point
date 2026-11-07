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
    return legacy_note_body if pending_note_change?

    general_note_entry&.body || legacy_note_body
  end

  def note_body=(value)
    @note_body = value.to_s.strip.presence
    @note_body_assigned = true
    self[:notes] = @note_body if has_attribute?(:notes)
  end

  def note_organization
    return organization if respond_to?(:organization) && organization.present?

    parent_note_organization
  end

  private

  def pending_note_change?
    return false unless has_attribute?(:notes)

    new_record? || will_save_change_to_attribute?('notes')
  end

  def legacy_note_body
    self[:notes] if has_attribute?(:notes)
  end

  def general_note_entry
    return note_entries.find { |entry| entry.kind == 'general' } if association(:note_entries).loaded?

    note_entries.find_by(kind: 'general') if persisted?
  end

  def parent_note_organization
    %i[supplier contactable goods_receipt purchase_request purchase_return purchase_order].each do |name|
      next unless respond_to?(name)

      parent = public_send(name)
      next unless parent

      return parent if parent.is_a?(Organization)
      return parent.organization if parent.respond_to?(:organization) && parent.organization.present?
    end
    nil
  end

  def general_note_changed?
    @note_body_assigned || (has_attribute?(:notes) && saved_change_to_attribute?('notes'))
  end

  def sync_general_note
    content = @note_body_assigned ? @note_body : legacy_note_body.to_s.strip.presence
    entry = note_entries.find_by(kind: 'general')
    if content.present?
      write_general_note(entry, content)
    else
      entry&.destroy!
    end
  ensure
    remove_instance_variable(:@note_body_assigned) if instance_variable_defined?(:@note_body_assigned)
    remove_instance_variable(:@note_body) if instance_variable_defined?(:@note_body)
  end

  def write_general_note(entry, content)
    organization = note_organization
    return note_entries.create!(kind: 'general', body: content, organization:) unless entry
    return if entry.body == content && entry.organization_id == organization&.id

    entry.update!(body: content, organization:)
  end
end
