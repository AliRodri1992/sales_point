# frozen_string_literal: true

module Onboarding
  class TerminalsUpdater
    def self.call(organization, params)
      new(organization, params).call
    end

    def initialize(organization, params)
      @organization = organization
      @params = params
    end

    def call
      branch = @organization.branches.not_deleted.where(status: true).first ||
               @organization.branches.not_deleted.first
      return false unless branch

      terminals = branch.terminals.active_records.order(:id).to_a
      return false if terminals.empty?

      terminals.each_with_index do |terminal, index|
        return false unless terminal.update(name: terminal_name(index))
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
