# frozen_string_literal: true

module Admin
  class OnboardingController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_organization
    before_action :authorize_onboarding

    def show
      load_onboarding
    end

    def update
      @step = normalized_step

      if update_current_step
        if @step == 5
          redirect_to admin_dashboard_path, flash: { swal_message: t('admin.onboarding.completed') }
        else
          redirect_to admin_onboarding_path(step: @step + 1)
        end
      else
        load_onboarding
        flash.now[:alert] = t('admin.onboarding.incomplete')
        render :show, status: :unprocessable_content
      end
    end

    private

    def set_organization
      @organization = current_user.organizations.active_records.first
      raise ActiveRecord::RecordNotFound unless @organization
    end

    def authorize_onboarding
      authorize :onboarding, :show?
    end

    def normalized_step
      value = params[:step].to_i
      value.between?(1, 5) ? value : 1
    end

    def update_current_step
      case @step
      when 1 then update_company
      when 2 then update_branch
      when 3 then update_terminals
      when 4 then update_payment
      when 5 then onboarding_complete?
      end
    rescue ActiveRecord::RecordInvalid, KeyError, ActionController::ParameterMissing
      false
    end

    def update_company
      @organization.update(company_params)
    end

    def update_branch
      branch = active_branch
      return false unless branch

      branch.update(branch_params)
    end

    def update_terminals
      branch = active_branch
      return false unless branch

      desired = terminal_count
      terminals = branch.terminals.active_records.order(:id).to_a

      ActiveRecord::Base.transaction do
        terminals.first(desired).each_with_index do |terminal, index|
          terminal.update!(name: terminal_name(index), code: terminal_code(index))
        end

        terminals.drop(desired).each do |terminal|
          terminal.update!(deleted_at: Time.current, status: :inactive)
        end

        (terminals.length...desired).each do |index|
          Terminal.create!(
            branch:,
            name: terminal_name(index),
            code: terminal_code(index),
            status: :active
          )
        end
      end

      true
    end

    def update_payment
      settings = @organization.organization_settings.first
      return false unless settings

      method = params.expect(payment: [:method]).fetch(:method)
      return false unless %w[cash card qr].include?(method)

      ActiveRecord::Base.transaction do
        settings.update!(payment_method: method)

        if method == 'cash'
          @organization.payment_integrations.where(deleted_at: nil).update_all(
            deleted_at: Time.current,
            status: 'inactive'
          )
        else
          integration = @organization.payment_integrations.find_or_initialize_by(provider: method)
          integration.update!(status: :pending, deleted_at: nil)
        end
      end

      true
    end

    def onboarding_complete?
      Onboarding::ProgressCalculator.call(@organization)[:percentage] == 100
    end

    def load_onboarding
      @step = normalized_step
      @branch = active_branch
      @settings = @organization.organization_settings.first
      @terminals = @branch&.terminals&.active_records&.order(:id) || []
      @migration = @organization.organization_migrations.first
      @progress = Onboarding::ProgressCalculator.call(@organization)
      @branch.build_address if @branch && @branch.address.nil?
    end

    def active_branch
      @organization.branches.not_deleted.where(status: true).first ||
        @organization.branches.not_deleted.first
    end

    def company_params
      params.expect(organization: %i[name tax_id business_sector])
    end

    def branch_params
      params.expect(
        branch: [
          :name,
          :phone,
          { address_attributes: %i[
            id street exterior_number interior_number neighborhood city state country postal_code
          ] }
        ]
      )
    end

    def terminal_count
      {
        '1' => 1,
        '2' => 2,
        '3_5' => 3,
        'over_5' => 6
      }.fetch(params.expect(terminals: [:count]).fetch(:count))
    end

    def terminal_name(index)
      params.dig(:terminal_names, index.to_s).presence ||
        I18n.t('registration.initial_terminal_name', number: index + 1)
    end

    def terminal_code(index)
      format('POS-%03d', index + 1)
    end
  end
end
