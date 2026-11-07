# frozen_string_literal: true

module Products
  class SavePriceList
    def initialize(list:, actor:, attributes:, reason: nil)
      @list = list
      @actor = actor
      @attributes = attributes
      @reason = reason
    end

    def call
      @list.transaction { persist_changes? }
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.cause.is_a?(PG::ExclusionViolation)

      @list.errors.add(:base, I18n.t('admin.catalog_design.overlapping_price'))
      false
    rescue ActiveRecord::RecordInvalid => e
      @list.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record == @list
      false
    end

    private

    def persist_changes?
      @list.lock! if @list.persisted?
      @list.assign_attributes(@attributes)
      changes = price_changes
      return missing_reason? if @reason.blank? && changes.any? { |item, _| item.persisted? }

      @list.save!
      changes.each { |item, previous| record_event(item, previous) }
      true
    end

    def price_changes
      @list.price_list_items.filter_map do |item|
        [item, item.price_in_database] if item.new_record? || item.will_save_change_to_price?
      end
    end

    def missing_reason?
      @list.errors.add(:base, I18n.t('admin.catalog_design.price_reason_required'))
      false
    end

    def record_event(item, previous)
      PriceChangeEvent.create!(organization: @list.organization, product: item.product, price_list_item: item,
                               actor: @actor, approved_by: @actor, approved_at: Time.current, status: 'approved',
                               previous_price: previous, new_price: item.price, currency: @list.currency,
                               reason: @reason.presence || I18n.t('admin.catalog_design.initial_price'))
    end
  end
end
