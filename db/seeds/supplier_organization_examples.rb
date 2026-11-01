# frozen_string_literal: true

# Adds only missing settings; never overwrites an existing tenant's preferences.
module SupplierOrganizationExamples
  def self.configure!(organization)
    settings = OrganizationSetting.find_or_initialize_by(organization:)
    if settings.new_record?
      settings.assign_attributes(base_currency: Currency.active.find_by!(code: 'MXN'),
                                 timezone: 'America/Mexico_City', payment_method: :cash)
    else
      settings.base_currency ||= Currency.active.find_by!(code: 'MXN')
      settings.timezone = 'America/Mexico_City' if settings.timezone.blank?
    end
    settings.save! if settings.new_record? || settings.changed?
    $stdout.puts "[SEEDS][CONFIGURACION][OK] organizacion_id=#{organization.id} " \
                 "moneda=#{settings.base_currency.code}"
    settings
  end
end
