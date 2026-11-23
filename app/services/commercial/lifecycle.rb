# frozen_string_literal: true

module Commercial
  class Lifecycle
    STATES = { 'activate' => 'active', 'pause' => 'paused', 'resume' => 'active', 'archive' => 'archived' }.freeze

    def initialize(record:, actor:)
      @record = record
      @actor = actor
    end

    def call(action)
      @record.with_lock do
        validate_transition!(action)
        previous_status = @record.status
        result = action == 'duplicate' ? duplicate : change_status(action)
        details = { from: previous_status, to: result.status }
        details[:source_id] = @record.id if action == 'duplicate'
        FinancialAuditEvent.record!(organization: result.organization, actor: @actor,
                                    event: "#{result.model_name.singular}.#{action}", subject: result, details:)
        result
      end
    end

    private

    def validate_transition!(action)
      if @actor && @record.transition_available?(action)
        return unless price_approval_required?(action)

        @record.errors.add(:base, I18n.t('admin.commercial.below_cost_forbidden'))
      else
        @record.errors.add(:status, :invalid)
      end
      raise ActiveRecord::RecordInvalid, @record
    end

    def price_approval_required?(action)
      return false unless @record.is_a?(PriceList) && %w[duplicate activate resume].include?(action)
      return false if PriceListPolicy.new(@actor, @record).below_cost?

      costs = Products::ListPriceCost.new(@record)
      at = Time.current
      @record.price_list_items.preload(:product, :product_presentation).any? do |item|
        (action == 'duplicate' || @record.available_row?(item, at:)) && costs.below_cost?(item)
      end
    end

    def change_status(action)
      @record.update!(status: STATES.fetch(action))
      @record
    end

    def duplicate
      copy = @record.dup
      copy.assign_attributes(code: nil, status: 'draft')
      copy.default_list = false if copy.is_a?(PriceList)
      copy_children_to(copy)
      copy.save!
      copy
    rescue ActiveRecord::RecordInvalid => e
      @record.errors.add(:base, e.record.errors.full_messages.to_sentence)
      raise ActiveRecord::RecordInvalid, @record
    end

    def copy_children_to(copy)
      child_associations.each do |name|
        @record.public_send(name).each { |child| copy.public_send(name) << child.dup }
      end
    end

    def child_associations
      @record.is_a?(PriceList) ? %i[price_list_items] : %i[promotion_conditions promotion_benefits]
    end
  end
end
