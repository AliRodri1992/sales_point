# frozen_string_literal: true

class RegistrationConfigurationProvisioner
  def self.call(organization:, params:)
    new(organization:, params:).call
  end

  def initialize(organization:, params:)
    @organization = organization
    @params = params
  end

  def call
    create_settings
    branch = create_branch
    create_terminals(branch)
    create_payment_integration
    create_migration if migration_setup?
  end

  private

  def create_settings
    OrganizationSetting.create!(
      organization: @organization,
      currency: parameter(:currency).upcase,
      timezone: 'UTC',
      payment_method: parameter(:payment_integration)
    )
  end

  def create_branch
    Branch.create!(
      organization: @organization,
      name: I18n.t('registration.initial_branch_name'),
      status: true
    )
  end

  def create_terminals(branch)
    terminal_count.times do |index|
      Terminal.create!(
        branch:,
        name: I18n.t('registration.initial_terminal_name', number: index + 1),
        code: format('POS-%03d', index + 1),
        status: :active
      )
    end
  end

  def create_payment_integration
    return if parameter(:payment_integration) == 'cash'

    PaymentIntegration.create!(
      organization: @organization,
      provider: parameter(:payment_integration),
      status: :pending
    )
  end

  def create_migration
    OrganizationMigration.create!(
      organization: @organization,
      volume: @params[:migration_volume],
      priority: @params[:migration_priority],
      status: :pending
    )
  end

  def terminal_count
    { '1' => 1, '2' => 2, '3_5' => 3, 'over_5' => 6 }.fetch(@params[:terminals].to_s, 1)
  end

  def migration_setup?
    @params[:setup_type] == 'migration'
  end

  def parameter(key)
    @params[key].to_s.strip
  end
end
