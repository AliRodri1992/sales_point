# frozen_string_literal: true

module Onboarding
  class ProgressCalculator
    REQUIRED_ADDRESS_FIELDS = %i[
      street
      exterior_number
      neighborhood
      city
      state
      country
      postal_code
    ].freeze

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

      applicable_sections = sections.reject { |section| section[:status] == 'not_applicable' }

      {
        sections:,
        percentage: overall_percentage(applicable_sections)
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
      return section(:branches, 0) unless branch

      branch_percentage = percentage_for([branch.name])
      address_percentage = percentage_for(
        REQUIRED_ADDRESS_FIELDS.map { |field| branch.address&.public_send(field) }
      )

      section(:branches, (branch_percentage + address_percentage) / 2)
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
      return section(:migration, 0, status: 'not_applicable') unless migration

      percentage = percentage_for([migration.volume, migration.priority])
      section(:migration, percentage)
    end

    def team_section
      section(:team, @organization.employees.active.exists? ? 100 : 0)
    end

    def settings
      @settings ||= @organization.organization_settings.first
    end

    def percentage_for(fields)
      return 0 if fields.empty?

      (fields.count(&:present?) * 100) / fields.length
    end

    def overall_percentage(sections)
      return 0 if sections.empty?

      (sections.sum { |section| section[:percentage] } / sections.length.to_f).round
    end

    def section(key, percentage, status: nil)
      {
        key:,
        percentage:,
        status: status || status_for(percentage)
      }
    end

    def status_for(percentage)
      return 'completed' if percentage == 100
      return 'not_started' if percentage.zero?

      'in_progress'
    end
  end
end
