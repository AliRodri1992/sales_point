# frozen_string_literal: true

module BranchesHelper
  def branch_operational_status(branch)
    colors = {
      'preparing' => 'bg-slate-100 text-slate-700',
      'active' => 'bg-emerald-100 text-emerald-800',
      'suspended' => 'bg-amber-100 text-amber-800',
      'closed' => 'bg-slate-200 text-slate-800'
    }
    styles = 'inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold'
    content_tag(:span, t("admin.branch_lifecycle.statuses.#{branch.operational_status}"),
                class: "#{styles} #{colors.fetch(branch.operational_status)}")
  end

  def branch_activation_requirements(branch)
    Branches::LifecycleRequirements.new(branch:, actor: current_user).activation
  end

  def branch_suspension_blockers(branch)
    Branches::LifecycleRequirements.new(branch:, actor: current_user).suspension_blockers
  end

  def branch_closure_blockers(branch)
    Branches::LifecycleRequirements.new(branch:, actor: current_user).closure_blockers
  end

  def branch_transition_blockers(branch, to_status)
    case to_status.to_s
    when 'active' then branch_activation_requirements(branch).reject { |_key, ready| ready }.keys
    when 'suspended' then branch_suspension_blockers(branch)
    when 'closed' then branch_closure_blockers(branch)
    else []
    end
  end

  def branch_blocker_path(branch, blocker)
    case blocker.to_sym
    when :outstanding_stock then admin_branch_inventories_path(branch)
    when :pending_requests then admin_purchase_requests_path
    when :pending_orders then admin_purchase_orders_path
    when :pending_returns then admin_purchase_returns_path
    when :assigned_team then admin_users_path
    else nil
    end
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
