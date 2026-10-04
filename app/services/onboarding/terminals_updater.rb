# frozen_string_literal: true

module Onboarding
  class TerminalsUpdater
    def self.call(organization, params, terminals: nil)
      new(organization, params, terminals).call
    end

    def initialize(organization, params, terminals)
      @organization = organization
      @params = params
      @terminals = terminals
    end

    def call
      branch = @organization.branches.not_deleted.where(status: true).first ||
               @organization.branches.not_deleted.first
      return false unless branch

      terminals = @terminals || branch.terminals.active_records.order(:id).to_a
      return false if terminals.empty?

      terminals.each_with_index do |terminal, index|
        terminal.assign_attributes(name: terminal_name(index))
        return false unless terminal.save(context: :onboarding_step_3)
      end

      true
    end

    private

    def terminal_name(index)
      @params.dig(:terminal_names, index.to_s).presence ||
        I18n.t('registration.initial_terminal_name', number: index + 1)
    end
  end
end
