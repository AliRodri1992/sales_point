# frozen_string_literal: true

module Products
  class SavePriceList
    def initialize(list:, actor:, attributes:, reason: nil)
      @list = list
      @actor = actor
      @attributes = attributes.to_h.with_indifferent_access
      @reason = reason
    end

    def call
      @list.transaction(requires_new: true) { persist_changes? }
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.cause.is_a?(PG::ExclusionViolation)

      retain_removals
      @list.errors.add(:base, I18n.t('admin.catalog_design.overlapping_price'))
      false
    rescue ActiveRecord::RecordInvalid => e
      retain_removals
      @list.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record == @list
      false
    end

    private

    def persist_changes?
      @list.lock! if @list.persisted?
      @retiring = assign_rows
      changes = price_changes
      unless permitted_changes?
        retain_removals
        return false
      end

      @retiring.each { |item| retire(item) }
      @list.save!
      changes.each { |item, previous| record_event(item, previous) }
      record_period_changes
      true
    end

    def assign_rows
      @list.assign_attributes(@attributes.except(:price_list_items_attributes))
      removed, kept = submitted_rows.partition { |row| ActiveModel::Type::Boolean.new.cast(row[:_destroy]) }
      @list.price_list_items_attributes = kept
      indexed = @list.price_list_items.select(&:persisted?).index_by { |item| item.id.to_s }
      removed.filter_map do |row|
        indexed.fetch(row[:id].to_s) { raise ActiveRecord::RecordNotFound } if row[:id].present?
      end.uniq
    end

    def submitted_rows
      rows = @attributes[:price_list_items_attributes] || []
      rows = rows.key?(:id) ? [rows] : rows.values if rows.is_a?(Hash)
      raise ActiveRecord::NestedAttributes::TooManyRecords if rows.size > 50

      rows
    end

    def retain_removals
      target = @list.association(:price_list_items).target
      Array(@retiring).each do |item|
        target << item unless target.include?(item)
        item.mark_for_destruction
      end
    end

    def price_changes
      @list.price_list_items.filter_map do |item|
        [item, item.price_in_database] if item.new_record? || item.will_save_change_to_price?
      end
    end

    def permitted_changes?
      return false unless valid_reason?

      cost = ListPriceCost.new(@list)
      below_cost = @list.price_list_items.select { |item| check_cost?(item) && cost.below_cost?(item) }
      return true if below_cost.empty? || PriceListPolicy.new(@actor, @list).below_cost?

      below_cost.each { |item| item.errors.add(:price, I18n.t('admin.commercial.below_cost_forbidden')) }
      false
    end

    def valid_reason?
      edited = @list.price_list_items.any? do |item|
        item.persisted? && item.changes_to_save.keys.intersect?(%w[price starts_at ends_at])
      end
      historical = edited || @retiring.any?
      return true if @reason.nil? && !historical
      return true if @reason.is_a?(String) && @reason.length <= 1000 && (!historical || @reason.present?)

      message = if !@reason.is_a?(String) || @reason.blank?
                  I18n.t('admin.catalog_design.price_reason_required')
                else
                  I18n.t('errors.messages.too_long', count: 1000)
                end
      @list.errors.add(:price_change_reason, message)
      false
    end

    def check_cost?(item)
      return false if @retiring.include?(item)
      return true if item.new_record? || item.will_save_change_to_price?

      extended_period?(item) || extended_period?(@list)
    end

    def extended_period?(record)
      previous_start = record.starts_at_in_database
      previous_end = record.ends_at_in_database
      (previous_start && (!record.starts_at || record.starts_at < previous_start)) ||
        (previous_end && (!record.ends_at || record.ends_at > previous_end))
    end

    def retire(item)
      item.retire!
      @list.association(:price_list_items).target.delete(item)
      audit_item('price_list.item_retired', item)
    end

    def record_period_changes
      @list.price_list_items.each do |item|
        next if item.saved_change_to_id?

        changes = item.saved_changes.slice('starts_at', 'ends_at')
        audit_item('price_list.item_period_changed', item, changes:) if changes.any?
      end
    end

    def audit_item(event, item, **details)
      FinancialAuditEvent.record!(organization: @list.organization, actor: @actor, event:, subject: @list,
                                  details: details.merge(price_list_item_id: item.id, reason: @reason))
    end

    def record_event(item, previous)
      PriceChangeEvent.create!(organization: @list.organization, product: item.product, price_list_item: item,
                               actor: @actor, approved_by: @actor, approved_at: Time.current, status: 'approved',
                               previous_price: previous, new_price: item.price, currency: @list.currency,
                               reason: @reason.presence || I18n.t('admin.catalog_design.initial_price'))
    end
  end
end
