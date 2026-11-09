# frozen_string_literal: true

module Products
  class SaveCatalogEntry
    attr_reader :pending

    def initialize(product:, actor:, attributes:)
      @product = product
      @actor = actor
      @attributes = attributes
      @pending = false
    end

    def call
      return save_new? if @product.new_record?

      @product.with_lock do
        raise ActiveRecord::RecordNotFound if @product.deleted_at.present?

        update_existing?
      end
    rescue ActiveRecord::RecordInvalid => e
      if e.record.is_a?(ProductBarcode) && e.record.primary?
        @product.errors.add(:barcode, :invalid)
      elsif e.record != @product
        @product.errors.add(:base, e.record.errors.full_messages.to_sentence)
      end
      false
    end

    private

    def save_new?
      @product.assign_attributes(@attributes)
      @product.transaction do
        @product.save!
        record_event(nil, @product.price,
                     initial_price_reason, approved: true)
      end
      true
    end

    def update_existing?
      previous = @product.price
      @product.assign_attributes(@attributes)
      return @product.save unless @product.will_save_change_to_price? && @product.price != previous
      return missing_reason? if @product.price_change_reason.blank?
      return false unless @product.valid?

      requested = @product.price
      @pending = !@actor.admin?
      @product.price = previous if @pending
      @product.save!
      record_event(previous, requested, @product.price_change_reason, approved: !@pending)
      true
    end

    def missing_reason?
      @product.errors.add(:price_change_reason, :blank)
      false
    end

    def initial_price_reason
      @product.price_change_reason.presence || I18n.t('admin.catalog_design.initial_price')
    end

    def base_currency
      @product.organization.organization_settings.active_records.first&.base_currency&.code || 'MXN'
    end

    def record_event(previous, requested, reason, approved:)
      @product.price_change_events.create!(organization: @product.organization, actor: @actor,
                                           previous_price: previous, new_price: requested, reason:,
                                           currency: base_currency,
                                           status: approved ? 'approved' : 'pending',
                                           approved_by: approved ? @actor : nil,
                                           approved_at: approved ? Time.current : nil)
    end
  end
end
