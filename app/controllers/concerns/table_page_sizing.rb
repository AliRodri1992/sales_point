# frozen_string_literal: true

module TablePageSizing
  private

  # Explicit URL parameters take precedence, without persisting a GET request.
  # Saved overrides belong to both the user and their current organization.
  def table_page_size_for(table_key)
    explicit = params[:per_page].to_s
    return explicit.to_i if TablePagePreference::OPTIONS.include?(explicit.to_i) && explicit == explicit.to_i.to_s

    saved = current_user.table_page_preferences.find_by(
      organization: current_organization, table_key: table_key
    )&.per_page
    saved || organization_default_table_page_size
  end

  def organization_default_table_page_size
    current_organization&.organization_settings&.active_records&.pick(:default_table_page_size) ||
      TablePagePreference::DEFAULT
  end
end
