# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierFormAuthorization do
  subject(:host) { Class.new { include SupplierFormAuthorization }.new }

  describe '#nested_section_permission' do
    it 'requires create permission for a new primary contact' do
      nested = { '0' => { name: 'New contact', primary: true } }

      expect(host.send(:nested_section_permission, nested, :contacts)).to eq(:create_contacts?)
    end

    it 'requires update permission for an existing primary contact' do
      nested = { '0' => { id: 41, name: 'Updated contact' } }

      expect(host.send(:nested_section_permission, nested, :contacts)).to eq(:update_contacts?)
    end

    it 'requires create permission for a missing fiscal address' do
      nested = { '0' => { street: 'Reforma', purpose: 'fiscal' } }

      expect(host.send(:nested_section_permission, nested, :addresses)).to eq(:create_addresses?)
    end

    it 'requires update permission for an existing fiscal address' do
      nested = { '0' => { id: 42, street: 'Reforma' } }

      expect(host.send(:nested_section_permission, nested, :addresses)).to eq(:update_addresses?)
    end
  end
end
