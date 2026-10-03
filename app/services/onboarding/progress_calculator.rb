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
        team_section
      ]
      { sections:, percentage: sections.sum { |section| section[:percentage] } / sections.length }
    end

    private

    def company_section
      fields = [@organization.name, @organization.business_sector, settings&.currency]
      section(:company, fields.count(&:present?) * 25)
    end

    def fiscal_section
      section(:fiscal, @organization.tax_id.present? ? 100 : 0)
    end

    def branch_section
      branch = @organization.branches.where(status: true).first
      percentage = branch ? (branch.address.present? ? 100 : 50) : 0
      section(:branches, percentage)
    end

    def terminal_section
      configured = @organization.branches.joins(:terminals).merge(Terminal.active_records).exists?
      section(:terminals, configured ? 100 : 0)
    end

    def payment_section
      configured = @organization.payment_integrations.active.exists? || settings.present?
      section(:payments, configured ? 100 : 0)
    end

    def team_section
      section(:team, @organization.employees.active.exists? ? 100 : 0)
    end

    def settings
      @settings ||= @organization.organization_settings.first
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