# frozen_string_literal: true

module CatalogAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :authorize_catalog_action
  end

  private

  def authorize_catalog_action
    return if controller_name == 'languages' && action_name == 'content'

    authorize controller_name.classify.constantize
  end
end
