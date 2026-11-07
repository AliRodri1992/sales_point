# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial configuration permissions' do
  let(:catalog_actions) { %i[index? show? create? update? destroy?] }
  let(:configuration_actions) { %i[create? update? destroy?] }
  let(:reader_permissions) { %w[products.access products.index products.show] }

  [PriceListPolicy, PromotionPolicy].each do |policy_class|
    it "denies anonymous access and configuration through #{policy_class}" do
      policy = policy_class.new(nil, policy_class == PriceListPolicy ? PriceList : Promotion)
      catalog_actions.each { |action| expect(policy.public_send(action)).to be(false) }
    end

    it "allows product readers to inspect but not configure through #{policy_class}" do
      reader = instance_double(User, admin?: false)
      allow(reader).to receive(:permission?) { |code| reader_permissions.include?(code) }
      policy = policy_class.new(reader, policy_class == PriceListPolicy ? PriceList : Promotion)
      expect(policy.index?).to be(true)
      expect(policy.show?).to be(true)
      configuration_actions.each { |action| expect(policy.public_send(action)).to be(false) }
    end
  end
end
