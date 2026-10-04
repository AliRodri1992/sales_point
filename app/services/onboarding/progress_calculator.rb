# frozen_string_literal: true

module Onboarding
  class ProgressCalculator
    def self.call(organization)
      new(organization).call
    end

    def initialize(organization)
      @organization = organization
    end

    def call
      sections = [
        company_section,
        fiscal_section,
        branch_section,
        terminal_section,
        payment_section,
        migration_section,
        team_section
      ]

      {
        sections:,
        percentage: sections.sum { |section| section[:percentage] } / sections.length
      }
    end

    private

    def company_section
      fields = [@organization.name, @organization.business_sector, settings&.currency, settings&.timezone]
      section(:company, percentage_for(fields))
    end

    def fiscal_section
      section(:fiscal, @organization.tax_id.present? ? 100 : 0)
    end

    def branch_section
      branch = @organization.branches.not_deleted.where(status: true).first
      percentage = if branch.nil?
                     0
                   elsif branch.address.present?
                     100
                   else
                     50
                   end
      section(:branches, percentage)
    end

    def terminal_section
      configured = @organization.branches.joins(:terminals).merge(Terminal.active_records).exists?
      section(:terminals, configured ? 100 : 0)
    end

    def payment_section
      section(:payments, settings&.payment_method.present? ? 100 : 0)
    end

    def migration_section
      migration = @organization.organization_migrations.first
      complete = migration.nil? || (migration.volume.present? && migration.priority.present?)
      section(:migration, complete ? 100 : 0)
    end

    def team_section
      section(:team, @organization.employees.active.exists? ? 100 : 0)
    end

    def settings
      @settings ||= @organization.organization_settings.first
    end

    def percentage_for(fields)
      (fields.count(&:present?) * 100) / fields.length
    end

    def section(key, percentage)
      { key:, percentage:, status: status_for(percentage) }
    end

    def status_for(percentage)
      return 'completed' if percentage == 100
      return 'not_started' if percentage.zero?

      'in_progress'
    end
  end
end
