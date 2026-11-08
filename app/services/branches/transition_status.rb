# frozen_string_literal: true

module Branches
  # All interactive lifecycle changes go through this atomic, audited service.
  class TransitionStatus
    ALLOWED = {
      'preparing' => %w[active closed],
      'active' => %w[suspended closed],
      'suspended' => %w[active closed],
      'closed' => []
    }.freeze

    class InvalidTransition < StandardError; end

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
      branch.with_lock do
        check_permission!
        check_transition!
        check_readiness!
        previous = branch.operational_status
        branch.lifecycle_transition_authorized = true
        branch.update!(operational_status: to, status: to == 'active')
        branch.branch_status_transitions.create!(
          changed_by: actor, from_status: previous, to_status: to, reason:
        )
      ensure
        branch.lifecycle_transition_authorized = false
      end
      true
    end

    private

    attr_reader :branch, :actor, :to, :reason

    def check_permission!
      allowed = actor&.admin? &&
                actor.organization_memberships.accessible.exists?(organization_id: branch.organization_id)
      reject!('not_authorized') unless allowed
    end

    def check_transition!
      reject!('invalid_transition') unless ALLOWED.fetch(branch.operational_status, []).include?(to)
      reject!('reason_required') if reason.blank?
      reject!('reason_too_long') if reason.length > 2000
    end

    def check_readiness!
      return if to == 'suspended'

      if to == 'active'
        reject!('organization_inactive') unless branch.organization&.active?
        reject!('missing_address') unless branch.address&.valid?
        reject!('missing_code') if branch.code.blank?
        team = Branch.team_assignments(branch.organization).where(branch_id: branch.id)
        reject!('missing_team') unless team.exists?
        return
      end

      # Closed branches must not retain active operational dependencies.
      reject!('open_operations') if branch.active_branch_operations?
      reject!('assigned_team') if branch.user_roles.active.exists?
      reject!('outstanding_stock') if branch.inventories.where('stock > 0').exists?
      return unless branch.organization&.active? && branch.organization.onboarding_completed?

      remaining = branch.organization.branches.not_deleted.where(operational_status: 'active').where.not(id: branch.id)
      reject!('last_active_branch') if branch.active? && remaining.none?
    end

    def reject!(code)
      raise InvalidTransition, I18n.t("admin.branch_lifecycle.errors.#{code}")
    end
  end
end
