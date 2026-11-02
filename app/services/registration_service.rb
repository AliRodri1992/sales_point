# frozen_string_literal: true

class RegistrationService
  include RegistrationInputValidation

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

  def parameter(key)
    @params[key].to_s.strip
  end

  def success_result
    Result.new(user: @user, organization: @user.employee.organization, errors: nil)
  end

  def failure_result(record)
    append_record_errors(record)
    step = @failure_step || failure_step_for(record)
    Result.new(user: @user, organization: nil, errors: @user.errors, step:)
  end

  def append_record_errors(record)
    return if record.equal?(@user)

    if record.is_a?(Employee) && record.errors.attribute_names == [:email]
      record.errors[:email].each { |message| @user.errors.add(:email, message) }
    else
      @user.errors.add(:base, record.errors.full_messages.to_sentence)
    end
  end

  def failure_step_for(record)
    case record
    when Organization then 3
    when Employee, User then 2
    when OrganizationSetting, Currency then 4
    else 5
    end
  end
end
