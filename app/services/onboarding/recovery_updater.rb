# frozen_string_literal: true

module Onboarding
  # Explicit, organization-scoped recovery for records missing from a legacy registration.
  class RecoveryUpdater
    def self.call(**)
      new(**).call
    end

    def initialize(organization:, user:, params:, record:, **options)
      @organization = organization
      @user = user
      @intent = options.fetch(:intent)
      @params = params
      @record = record
      @branch = options[:branch]
      @changed = false
    end

    def call
      result = false
      @organization.with_lock do
        result = @intent == 'terminal' ? create_terminal : create_team_profile
        record_progress if result && @changed
      end
      result
    rescue ActiveRecord::RecordInvalid => e
      @record.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record.equal?(@record)
      false
    end

    private

    def create_terminal
      branch = @organization.branches.not_deleted.where(status: true).find_by(id: @branch&.id)
      unless branch
        @record.errors.add(:base, I18n.t('admin.onboarding_ui.recovery.active_branch_required'))
        return false
      end
      return true if branch.terminals.active_records.exists?

      @record.assign_attributes(branch:, name: @params.expect(recovery: [:name])[:name],
                                code: next_code(branch), status: :active)
      @changed = @record.save!
    end

    def next_code(branch)
      number = 1
      number += 1 while branch.terminals.with_deleted.exists?(code: format('POS-%03d', number))
      format('POS-%03d', number)
    end

    def create_team_profile
      return true if @organization.employees.active.exists?

      if @organization.employees.exists?(email: @user.email)
        @record.errors.add(:base, I18n.t('admin.onboarding_ui.recovery.existing_profile'))
        return false
      end
      @record.assign_attributes(@params.expect(recovery: %i[first_name last_name]))
      @record.assign_attributes(organization: @organization, email: @user.email, status: :active)
      @record.save!
      @user.update!(employee: @record) if @user.employee_id.nil?
      @changed = true
    end

    def record_progress
      progress = ProgressSynchronizer.call(organization: @organization)
      terminal = @intent == 'terminal'
      Auditor.call(organization: @organization, user: @user, action: 'step_updated',
                   step: terminal ? 3 : 5, section: terminal ? :terminals : :team,
                   metadata: { 'percentage' => progress[:percentage], 'created_record_id' => @record.id })
    end
  end
end
