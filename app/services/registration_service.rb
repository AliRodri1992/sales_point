# frozen_string_literal: true

class RegistrationService
  Result = Struct.new(:user, :organization, :errors, keyword_init: true) do
    def success?
      errors.blank? && user&.persisted?
    end
  end

  def self.call(resource:, params:)
    new(resource:, params:).call
  end

  def initialize(resource:, params:)
    @user = resource
    @params = params
    @result = nil
  end

  def call
    ApplicationRecord.transaction do
      organization = create_organization
      employee = create_employee(organization)
      prepare_user(employee)
      save_user_or_rollback
      create_membership(organization)
      provision_access
      create_initial_configuration(organization)
      @result = Result.new(user: @user, organization:, errors: nil)
    end
    @result
  rescue ActiveRecord::RecordInvalid => e
    add_record_error(e.record)
    Result.new(user: @user, organization: nil, errors: @user.errors)
  end

  private

  def create_organization
    validate_terms!
    Organization.create!(
      name: @params[:company_name].to_s.strip,
      tax_id: @params[:tax_id].to_s.strip.upcase,
      business_sector: @params[:business_sector],
      status: :active
    )
  end

  def create_employee(organization)
    Employee.create!(
      organization:,
      first_name: @params[:first_name].to_s.strip,
      last_name: @params[:last_name].to_s.strip,
      email: @user.email,
      status: :active
    )
  end

  def prepare_user(employee)
    @user.assign_attributes(
      employee:,
      user_type: :employee,
      status: :active,
      terms_accepted_at: Time.current
    )
  end

  def save_user_or_rollback
    return if @user.save

    @result = Result.new(user: @user, organization: nil, errors: @user.errors)
    raise ActiveRecord::Rollback, 'User validation failed'
  end

  def create_membership(organization)
    OrganizationMembership.create!(organization:, user: @user, status: :active)
  end

  def provision_access
    role = SystemRole.available.find_by!(code: 'administrator')
    AdministratorPermissionProvisioner.call(role:)
    UserRole.create!(user: @user, system_role: role)
  end

  def create_initial_configuration(organization)
    create_settings(organization)
    branch = create_branch(organization)
    create_terminals(branch)
    create_payment_integration(organization)
    create_migration(organization) if @params[:setup_type] == 'migration'
  end

  def create_settings(organization)
    OrganizationSetting.create!(
      organization:,
      currency: @params[:currency].to_s.upcase,
      timezone: 'UTC',
      payment_method: @params[:payment_integration]
    )
  end

  def create_branch(organization)
    Branch.create!(
      organization:,
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

  def create_payment_integration(organization)
    return if @params[:payment_integration] == 'cash'

    PaymentIntegration.create!(
      organization:,
      provider: @params[:payment_integration],
      status: :pending
    )
  end

  def create_migration(organization)
    OrganizationMigration.create!(
      organization:,
      volume: @params[:migration_volume],
      priority: @params[:migration_priority],
      status: :pending
    )
  end

  def terminal_count
    { '1' => 1, '2' => 2, '3_5' => 3, 'over_5' => 6 }.fetch(@params[:terminals].to_s, 1)
  end

  def validate_terms!
    return if @params[:terms].to_s == '1'

    @user.errors.add(:base, I18n.t('devise.registrations.new.client_validation_terms'))
    raise ActiveRecord::RecordInvalid, @user
  end

  def add_record_error(record)
    @user.errors.add(:base, record.errors.full_messages.to_sentence)
  end
end
