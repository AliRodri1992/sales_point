# frozen_string_literal: true

module Branches
  # Authorizes, validates and audits every branch lifecycle transition atomically.
  class TransitionStatus
    ALLOWED = {
      'preparing' => %w[active closed],
      'active' => %w[suspended closed],
      'suspended' => %w[active closed],
      'closed' => []
    }.freeze

    class InvalidTransition < StandardError
      attr_reader :code

      def initialize(code)
        @code = code.to_s
        super(I18n.t("admin.branch_lifecycle.errors.#{code}"))
      end
    end

    def self.call(branch:, actor:, to:, reason:)
      new(branch:, actor:, to:, reason:).call
    end

    def initialize(branch:, actor:, to:, reason:)
      @branch = branch
      @actor = actor
      @to = to.to_s
      @reason = reason.to_s.strip
    end

    def call
      branch.organization.with_lock do
        branch.with_lock do
          check_permission!
          check_transition!
          check_readiness!
          persist_transition!
        ensure
          branch.lifecycle_transition_authorized = false
        end
      end
      true
    end

    private

    attr_reader :branch, :actor, :to, :reason

    def persist_transition!
      previous = branch.operational_status
      branch.lifecycle_transition_authorized = true
      branch.update!(operational_status: to, status: to == 'active')
      branch.branch_status_transitions.create!(
        changed_by: actor, from_status: previous, to_status: to, reason:
      )
    end

    def check_permission!
      permitted = actor&.admin? &&
                  actor.organization_memberships.accessible.exists?(organization_id: branch.organization_id)
      reject!('not_authorized') unless permitted
    end

    def check_transition!
      reject!('invalid_transition') unless ALLOWED.fetch(branch.operational_status, []).include?(to)
      reject!('reason_required') if reason.blank?
      reject!('reason_too_long') if reason.length > 2000
    end

    def check_readiness!
      requirements = LifecycleRequirements.new(branch:, actor:)
      case to
      when 'active'
        requirements.activation.each do |requirement, ready|
          reject!("missing_#{requirement}") unless ready
        end
      when 'suspended'
        blockers = requirements.suspension_blockers
        reject!(blockers.first) if blockers.any?
      when 'closed'
        blockers = requirements.closure_blockers
        reject!(blockers.first) if blockers.any?
      end
    end

    def reject!(code)
      raise InvalidTransition, code
    end
  end
end
