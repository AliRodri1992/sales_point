# frozen_string_literal: true

module CatalogNavigation
  extend ActiveSupport::Concern

  included do
    helper_method :catalog_back_path
  end

  private

  def catalog_back_path(model)
    policy(model).index? ? polymorphic_path([:admin, model]) : admin_dashboard_path
  end

  def redirect_without_catalog_listing(record, action)
    return if policy(record.class).index?

    message = t("admin.#{controller_name}.#{action}")
    redirect_to catalog_write_destination(record, action), status: :see_other, flash: { swal_message: message }
  end

  def catalog_write_destination(record, action)
    return admin_dashboard_path if action == :destroyed
    return polymorphic_path([:admin, record]) if policy(record).show?
    return new_polymorphic_path([:admin, record.class]) if action == :created

    edit_polymorphic_path([:admin, record])
  end
end
