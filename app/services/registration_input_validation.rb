# frozen_string_literal: true

# Validates registration options before creating the business or granting access.
module RegistrationInputValidation
  private

  def validate_configuration!
    validate_business_configuration!
    validate_terminal_configuration!
    validate_migration_configuration! if parameter(:setup_type) == 'migration'
  end

  def validate_business_configuration!
    reject_registration!(:setup_type, 1) unless %w[new migration].include?(parameter(:setup_type))
    reject_registration!(:business_sector, 4) unless valid_business_sector?
    reject_registration!(:currency, 4) unless Currency.active.exists?(code: parameter(:currency).upcase)
    reject_registration!(:timezone, 4) unless OrganizationSetting::ONBOARDING_TIMEZONES.include?(timezone)
  end

  def validate_terminal_configuration!
    reject_registration!(:branches, 4) if parameter(:branches).present? && parameter(:branches) != '1'
    reject_registration!(:terminals, 5) unless valid_terminal_count?
    reject_registration!(:payment_integration, 5) unless valid_payment_method?
  end

  def validate_migration_configuration!
    reject_registration!(:migration_volume, 4) unless valid_migration_volume?
    reject_registration!(:migration_priority, 4) unless valid_migration_priority?
  end

  def valid_business_sector?
    Organization::ONBOARDING_BUSINESS_SECTORS.include?(parameter(:business_sector))
  end

  def valid_payment_method?
    OrganizationSetting.payment_methods.key?(parameter(:payment_integration))
  end

  def valid_migration_volume?
    OrganizationMigration.volumes.value?(parameter(:migration_volume))
  end

  def valid_migration_priority?
    OrganizationMigration.priorities.value?(parameter(:migration_priority))
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

end
