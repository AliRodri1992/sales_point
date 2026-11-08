# frozen_string_literal: true

module BranchesHelper
  def branch_operational_status(branch)
    content_tag(:span, t("admin.branch_lifecycle.statuses.#{branch.operational_status}"),
                class: 'branch-status-card')
  end

  def branch_required_label(text)
    safe_join([text, content_tag(:span, ' *', class: 'branch-required-mark', aria: { hidden: true })])
  end

  def branch_field_aria(record, attribute, required: false)
    error = record.errors[attribute].any?
    attributes = { invalid: error }
    attributes[:required] = true if required
    attributes[:describedby] = "#{record.class.name.underscore}_#{attribute}_error" if error
    attributes
  end

  def branch_country_aria(branch, address)
    attributes = branch_field_aria(address, :country, required: true)
    return attributes if branch.errors[:address].empty? || address.errors[:country].any?

    attributes.merge(invalid: true, describedby: 'branch_address_error')
  end

  def branch_mobile(branch)
    branch.phones.find { |phone| phone.deleted_at.nil? && phone.kind == 'mobile' && phone.primary? }
  end

  def branch_location(branch)
    address = branch.address
    return t('admin.branch_workspace.location_pending') unless address

    location = [address.city, address.state, address.country&.localized_name].compact_blank.join(' · ')
    location.presence || t('admin.branch_workspace.location_pending')
  end

  def branch_code(branch)
    branch.code.presence || "##{branch.id}"
  end

  def branch_country_options(address)
    countries = Country.active.ordered.to_a
    retained = Country.with_deleted.find_by(id: address.country_id)
    countries << retained if retained && countries.none? { |country| country.id == retained.id }
    countries.map do |country|
      required = Addresses::CountryRules.new(country.iso_alpha2).required_fields.join(' ')
      [country.localized_name, country.id, { data: { country_code: country.iso_alpha2, required_fields: required } }]
    end
  end

  def branch_filter_badges(filters, countries)
    filters.filter_map do |key, value|
      next if value.blank?

      label = t("admin.branch_workspace.filters.#{key}")
      display = case key
                when 'status' then t("admin.branch_lifecycle.statuses.#{value}")
                when 'contact', 'team' then t("admin.branch_workspace.options.#{value}")
                when 'country_id' then countries.find { |country| country.id.to_s == value }&.localized_name
                when 'created_from', 'created_to' then l(Date.iso8601(value))
                else value
                end
      [key, "#{label}: #{display}"]
    end
  end

  def branch_filter_removal_path(key, filters)
    values = branch_directory_parameters.merge(filters).except(key, 'page').compact_blank
    admin_branches_path(values)
  end

  def branch_contact_link(branch)
    phone = branch_mobile(branch)
    return content_tag(:span, t('admin.branch_workspace.contact_pending'), class: 'branch-muted') unless phone

    link_to(phone.number, "tel:#{phone.number}", class: 'branch-contact-link')
  end
end
