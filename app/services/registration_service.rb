# frozen_string_literal: true

class RegistrationService
  Result = Struct.new(:user, :organization, :errors, :step, keyword_init: true) do
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
  end

  def call
    ApplicationRecord.transaction { register }
    success_result
  rescue ActiveRecord::RecordInvalid => e
    failure_result(e.record)
  end

  private

  def register
    validate_terms!
    validate_configuration!
    organization = create_organization
    employee = create_employee(organization)
    prepare_user(employee)
    save_user!
    create_membership(organization)
    provision_access
    RegistrationConfigurationProvisioner.call(organization:, params: @params)
  end

  def create_organization
    Organization.create!(
      name: parameter(:company_name),
      tax_id: parameter(:tax_id).upcase,
      business_sector: @params[:business_sector],
      status: :active
    )
  end

  def create_employee(organization)
    Employee.create!(
      organization:,
      first_name: parameter(:first_name),
      last_name: parameter(:last_name),
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

  def save_user!
    return if @user.save

    raise ActiveRecord::RecordInvalid, @user
  end

  def create_membership(organization)
    OrganizationMembership.create!(organization:, user: @user, status: :active)
  end

  def provision_access
    role = SystemRole.available.find_by!(code: 'administrator')
    AdministratorPermissionProvisioner.call(role:)
    UserRole.create!(user: @user, system_role: role)
  end

  def validate_terms!
    return if ActiveModel::Type::Boolean.new.cast(@params[:terms])

    reject_registration!(:terms, 5)
  end

  def validate_configuration!
    reject_registration!(:setup_type, 1) unless %w[new migration].include?(parameter(:setup_type))
    reject_registration!(:business_sector, 4) unless Organization::ONBOARDING_BUSINESS_SECTORS.include?(parameter(:business_sector))
    reject_registration!(:currency, 4) unless Currency.active.exists?(code: parameter(:currency).upcase)
    reject_registration!(:timezone, 4) unless OrganizationSetting::ONBOARDING_TIMEZONES.include?(timezone)
    reject_registration!(:branches, 4) unless parameter(:branches).blank? || parameter(:branches) == '1'
    reject_registration!(:terminals, 5) unless valid_terminal_count?
    reject_registration!(:payment_integration, 5) unless OrganizationSetting.payment_methods.key?(parameter(:payment_integration))

    return unless parameter(:setup_type) == 'migration'

    reject_registration!(:migration_volume, 4) unless OrganizationMigration.volumes.value?(parameter(:migration_volume))
    reject_registration!(:migration_priority, 4) unless OrganizationMigration.priorities.value?(parameter(:migration_priority))
  end

  def valid_terminal_count?
    %w[3_5 over_5].include?(parameter(:terminals)) ||
      parameter(:terminals).match?(/\A[1-6]\z/)
  end

  def timezone
    @params[:timezone].presence || 'America/Mexico_City'
  end

  def reject_registration!(key, step)
    @failure_step = step
    @user.errors.add(:base, I18n.t("registration.validation.#{key}"))
    raise ActiveRecord::RecordInvalid, @user
  end

  def parameter(key)
    @params[key].to_s.strip
  end

  def success_result
    Result.new(user: @user, organization: @user.employee.organization, errors: nil)
  end

  def failure_result(record)
    @user.errors.add(:base, record.errors.full_messages.to_sentence) unless record.equal?(@user)
    step = @failure_step || case record
                           when Organization then 3
                           when Employee, User then 2
                           when OrganizationSetting, Currency then 4
                           else 5
                           end
    Result.new(user: @user, organization: nil, errors: @user.errors, step:)
  end
end
