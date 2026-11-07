# frozen_string_literal: true

module Admin
  class PriceChangeEventsController < ApplicationController
    before_action :authenticate_user!

    def update
      event = scoped_price_event

      Products::DecidePriceChange.new(event:, actor: current_user, decision: params.require(:decision)).call
      redirect_to admin_product_path(event.product), notice: t('admin.catalog_design.price_decided'), status: :see_other
    rescue Products::DecidePriceChange::StalePrice, ArgumentError
      redirect_to admin_products_path, alert: t('admin.catalog_design.stale_price'), status: :see_other
    end

    private

    def scoped_price_event
      raise Pundit::NotAuthorizedError unless current_user.admin?

      current_organization&.price_change_events&.find(params[:id]) || raise(ActiveRecord::RecordNotFound)
    end
  end
end
