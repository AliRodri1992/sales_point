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
    return if @params[:terms].to_s == '1'

    @user.errors.add(:base, I18n.t('devise.registrations.new.client_validation_terms'))
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
    Result.new(user: @user, organization: nil, errors: @user.errors)
  end
end
