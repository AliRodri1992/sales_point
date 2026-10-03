# frozen_string_literal: true

module Admin
  class OnboardingController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_organization
    before_action :authorize_onboarding

    def show
      @step = normalized_step
      @branch = active_branch
      @settings = @organization.organization_settings.first
      @terminals = @branch.terminals.active_records.order(:id)
      @migration = @organization.organization_migrations.first
      @progress = Onboarding::ProgressCalculator.call(@organization)
    end

    def update
      @step = normalized_step
      result = update_step

      if result
        if @step == final_step
          redirect_to admin_dashboard_path,
                      flash: { swal_message: t('.completed') }
        else
          redirect_to admin_onboarding_path(step: @step + 1)
        end
      else
        prepare_form
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
      value.between?(1, final_step) ? value : 1
    end

    def final_step
      5
    end

    def active_branch
      @organization.branches.not_deleted.where(status: true).first ||
        @organization.branches.not_deleted.first
    end

    def update_step
      case @step
      when 1 then update_company
      when 2 then update_branch
      when 3 then update_terminals
      when 4 then update_payments
      when 5 then complete_onboarding?
      end
    end

    def update_company
      @organization.update(company_params)
    end

    def update_branch
      return false unless @branch

      @branch.update(branch_params)
    end

    def update_terminals
      return false unless @branch

      desired_count = terminal_count
      current_terminals = @branch.terminals.active_records.order(:id).to_a

      ActiveRecord::Base.transaction do
        current_terminals.first(desired_count).each_with_index do |terminal, index|
          terminal.update!(name: terminal_name(index), code: terminal_code(index))
        end

        current_terminals.drop(desired_count).each do |terminal|
          terminal.update!(deleted_at: Time.current, status: :inactive)
        end

        (current_terminals.length...desired_count).each do |index|
          Terminal.create!(
            branch: @branch,
            name: terminal_name(index),
            code: terminal_code(index),
            status: :active
          )
        end
      end

      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    def update_payments
      return false unless @settings

      ActiveRecord::Base.transaction do
        payment_method = params.require(:payment).fetch(:method)
        @settings.update!(payment_method:)

        @organization.payment_integrations.where.not(deleted_at: nil).update_all(deleted_at: nil) if false

        if payment_method == 'cash'
          @organization.payment_integrations.where(deleted_at: nil).update_all(
            deleted_at: Time.current,
            status: 'inactive'
          )
        else
          integration = @organization.payment_integrations.find_or_initialize_by(
            provider: payment_method
          )
          integration.assign_attributes(status: :pending, deleted_at: nil)
          integration.save!
        end
      end

      true
    rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing
      false
    end

    def complete_onboarding?
      return true if @progress[:percentage] == 100

      errors.add(:base, t('.incomplete'))
      false
    end

    def prepare_form
      @branch ||= active_branch
      @settings ||= @organization.organization_settings.first
      @terminals ||= @branch&.terminals&.active_records&.order(:id) || []
      @migration ||= @organization.organization_migrations.first
      @progress = Onboarding::ProgressCalculator.call(@organization)
    end

    def company_params
      params.expect(
        organization: %i[name tax_id business_sector]
      )
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
      value = params.require(:terminals).fetch(:count)
      {
        '1' => 1,
        '2' => 2,
        '3_5' => 3,
        'over_5' => 6
      }.fetch(value)
    rescue KeyError, ActionController::ParameterMissing
      raise ActiveRecord::RecordInvalid.new(@branch)
    end

    def terminal_name(index)
      params.dig(:terminal_names, index.to_s).presence ||
        I18n.t('registration.initial_terminal_name', number: index + 1)
    end

    def terminal_code(index)
      format('POS-%03d', index + 1)
    end

    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end
  end
end
