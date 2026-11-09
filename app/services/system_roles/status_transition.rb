# frozen_string_literal: true

module SystemRoles
  class StatusTransition
    class InvalidTransition < StandardError
      attr_reader :key

      def initialize(key)
        @key = key
        super(I18n.t("admin.system_roles.lifecycle.errors.#{key}"))
      end
    end

    def initialize(role:, actor:, target:, **confirmation)
      @role = role
      @actor = actor
      @target = target.to_s
      @reason = confirmation.fetch(:reason).to_s.strip
      @review_token = confirmation.fetch(:review_token)
      @confirmed = ActiveModel::Type::Boolean.new.cast(confirmation.fetch(:confirmed))
    end

    def call!
      @role.with_lock do
        authorize!
        validate_transition!
        impact = StatusImpact.new(@role)
        validate_review!(impact)
        validate_target!(impact)
        persist!(impact)
      end
      @role
    end

    private

    def authorize!
      raise Pundit::NotAuthorizedError unless @actor&.active? && @actor.deleted_at.nil? &&
                                              SystemRolePolicy.new(@actor, @role).change_status?
    end

    def validate_transition!
      allowed = SystemRole::STATUS_TRANSITIONS.fetch(@role.status, [])
      reject!(:invalid_transition) unless allowed.include?(@target)
      reject!(:reason_required) if @reason.blank? || @reason.length > 1000
      reject!(:confirmation_required) unless @confirmed
    end

    def validate_review!(impact)
      review = StatusReview.new(role: @role, actor: @actor, target: @target, impact:)
      reject!(:review_expired) unless review.valid?(@review_token)
    end

    def validate_target!(impact)
      reject!(:permissions_required) if @target == 'active' && impact.counts[:permissions].zero?
      reject!(:assignments_remain) if @target == 'deprecated' && impact.counts[:assignments].positive?
    end

    def persist!(impact)
      previous = @role.status
      @role.assign_attributes(status: @target, deleted_at: @target == 'deprecated' ? Time.current : nil)
      @role.save!(context: :status_transition)
      @role.status_events.create!(actor: @actor, from_status: previous, to_status: @target,
                                  reason: @reason, impact: impact.counts)
    end

    def reject!(key)
      raise InvalidTransition, key
    end
  end
end
