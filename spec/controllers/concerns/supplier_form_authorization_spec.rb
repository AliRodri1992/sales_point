# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierFormAuthorization do
  subject(:host) { Class.new { include SupplierFormAuthorization }.new }

  describe '#nested_section_permissions' do
    it 'requires create permission for a new primary contact' do
      expect(host.send(:nested_section_permissions, { '0' => { name: 'New contact' } }, :contacts))
        .to eq([:create_contacts?])
    end

    it 'requires update permission for an existing primary contact' do
      expect(host.send(:nested_section_permissions, { '0' => { id: 41, name: 'Updated' } }, :contacts))
        .to eq([:update_contacts?])
    end

    it 'requires create and update for a mixed request' do
      nested = { '0' => { id: 41, name: 'Updated' }, '1' => { name: 'New' } }

      expect(host.send(:nested_section_permissions, nested, :contacts))
        .to contain_exactly(:update_contacts?, :create_contacts?)
    end

    it 'requires destroy permission for removing an existing address' do
      expect(host.send(:nested_section_permissions, [{ id: 42, _destroy: '1' }], :addresses))
        .to eq([:destroy_addresses?])
    end

    it 'ignores deletion of an unsaved nested record' do
      expect(host.send(:nested_section_permissions, [{ name: 'Discarded', _destroy: true }], :contacts))
        .to be_empty
    end

    it 'requires all three permissions and does not repeat them' do
      nested = [{ name: 'New' }, { id: 5, name: 'Edited' },
                { id: 6, _destroy: 'true' }, { id: 7, _destroy: '1' }]
      expect(host.send(:nested_section_permissions, nested, :contacts))
        .to contain_exactly(:create_contacts?, :update_contacts?, :destroy_contacts?)
    end
  end
end
