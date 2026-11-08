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
      case to
      when 'active' then check_activation!
      when 'suspended' then check_last_active_branch!
      when 'closed' then check_closure!
      end
    end

    def check_activation!
      reject!('organization_inactive') unless branch.organization&.active?
      reject!('missing_address') unless branch.address&.valid?
      reject!('missing_code') if branch.code.blank?
      settings = branch.organization.organization_settings.active_records.first
      reject!('missing_currency') unless settings&.base_currency&.active?
      team = Branch.team_assignments(branch.organization).where(branch_id: branch.id)
      reject!('missing_team') unless team.exists?
    end

    def check_closure!
      reject!('open_operations') if branch.operational_dependencies?
      reject!('assigned_team') if branch.user_roles.active.exists?
      check_last_active_branch!
    end

    def check_last_active_branch!
      return unless branch.organization&.active? && branch.organization.onboarding_completed?
      return unless branch.active?

      remaining = branch.organization.branches.not_deleted.where(operational_status: 'active').where.not(id: branch.id)
      reject!('last_active_branch') if remaining.none?
    end

    def reject!(code)
      raise InvalidTransition, I18n.t("admin.branch_lifecycle.errors.#{code}")
    end
  end
end
