# frozen_string_literal: true

module Admin
  class SupplierLocationsController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    before_action :authenticate_user!
    before_action :authorize_supplier

    def suggest
      attrs = location_params
      address = @supplier.addresses.new(attrs)
      result = Geocoding::MapboxValidateAddressService.new(address).call
      unless result[:valid]
        Rails.logger.warn('[SupplierLocations] Mapbox returned no valid location; check MAPBOX_TOKEN and address')
        return render json: { error: 'location_unavailable' }, status: :service_unavailable
      end

      signature = Rails.application.message_verifier('supplier-address-location')
                       .generate(address.geocoding_fingerprint, expires_in: 20.minutes)
      response.headers['Cache-Control'] = 'private, no-store'
      render json: result.slice(:latitude, :longitude, :full_address, :confidence).merge(signature:)
    end

    def map
      data = Geocoding::MapboxStaticMapService.new.call(
        latitude: params[:latitude], longitude: params[:longitude]
      )
      return head :service_unavailable unless data

      response.headers['Cache-Control'] = 'private, max-age=120'
      send_data data, type: 'image/png', disposition: 'inline'
    end

    private

    def not_found = head(:not_found)

    def authorize_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:id])
      authorize @supplier, :manage_addresses?
    end

    def location_params
      attrs = %i[street exterior_number interior_number neighborhood city state postal_code country_id]
      permitted = params.expect(address: attrs)
      country_id = permitted[:country_id]
      Country.active.find(country_id) if country_id.present?
      permitted
    end
  end
end
