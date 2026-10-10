# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Onboarding::BranchUpdater, type: :service do
  describe '.call' do
    it 'returns false when the organization has no branch to update' do
      organization = create(:organization)

      result = described_class.call(
        organization,
        ActionController::Parameters.new(branch: { name: 'Sucursal Centro' })
      )

      expect(result).to be(false)
    end

    it 'updates the active branch and its nested address' do
      organization = create(:organization)
      branch = create(:branch, organization:, name: 'Sucursal Original')
      params = ActionController::Parameters.new(
        branch: {
          name: 'Sucursal Actualizada',
          phone: '5559876543',
          address_attributes: {
            id: branch.address.id,
            street: 'Av. Insurgentes',
            city: 'Tlalnepantla'
          }
        }
      )

      result = described_class.call(organization, params)

      expect(result).to be(true)
      expect(branch.reload.name).to eq('Sucursal Actualizada')
      expect(branch.phone).to eq('5559876543')
      expect(branch.address.reload).to have_attributes(
        street: 'Av. Insurgentes',
        city: 'Tlalnepantla'
      )
    end

    it 'falls back to a non-deleted branch when no active branch exists' do
      organization = create(:organization)
      branch = create(:branch, organization:, status: false, name: 'Sucursal Inactiva')
      params = ActionController::Parameters.new(branch: { name: 'Sucursal Actualizada' })

      expect(described_class.call(organization, params)).to be(true)
      expect(branch.reload.name).to eq('Sucursal Actualizada')
    end

    it 'uses the explicitly supplied branch instead of selecting another one' do
      organization = create(:organization)
      first_branch = create(:branch, organization:, name: 'Primera Sucursal')
      selected_branch = create(:branch, organization:, name: 'Sucursal Seleccionada')
      params = ActionController::Parameters.new(branch: { name: 'Sucursal Modificada' })

      expect(described_class.call(organization, params, branch: selected_branch)).to be(true)
      expect(selected_branch.reload.name).to eq('Sucursal Modificada')
      expect(first_branch.reload.name).to eq('Primera Sucursal')
    end

    it 'creates and persists an address when the selected branch has none' do
      organization = create(:organization)
      branch = create(:branch, :without_address, organization:)
      params = ActionController::Parameters.new(
        branch: {
          name: 'Sucursal Con Dirección',
          address_attributes: {
            street: 'Av. Reforma',
            exterior_number: '100',
            neighborhood: 'Centro',
            city: 'Cuautitlán',
            state: 'Estado de México',
            country: 'MX',
            postal_code: '54800'
          }
        }
      )

      expect(described_class.call(organization, params, branch:)).to be(true)
      expect(branch.reload.address).to have_attributes(
        street: 'Av. Reforma',
        postal_code: '54800'
      )
    end
  end
end
