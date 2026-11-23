# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogPolicy do
  { LanguagePolicy => 'languages', ProductPolicy => 'products', ClientPolicy => 'customers',
    CategoryPolicy => 'categories', UserPolicy => 'users' }.each do |policy_class, prefix|
    describe policy_class do
      let(:user) { build(:user) }
      let(:permissions) { [] }
      let(:policy) { policy_class.new(user, policy_class == UserPolicy ? User : Object.new) }

      before do
        allow(user).to receive(:admin?).and_return(false)
        allow(user).to receive(:permission?) { |code| permissions.include?(code) }
      end

      CatalogPolicy::ACTIONS.each do |action|
        it "requires the specific #{action} permission rather than module access alone" do
          permissions << "#{prefix}.access"
          expect(policy.public_send("#{action}?")).to be(false)
        end

        it "permits #{action} independently of the other CRUD actions" do
          permissions.push("#{prefix}.access", "#{prefix}.#{action}", 'users.invite')
          expect(policy.public_send("#{action}?")).to be(true)
          (CatalogPolicy::ACTIONS - [action]).each do |other|
            expect(policy.public_send("#{other}?")).to be(false)
          end
        end

        it "blocks #{action} when the module is disabled" do
          permissions.push("#{prefix}.#{action}", 'users.invite')
          expect(policy.public_send("#{action}?")).to be(false)
        end
      end
    end
  end

  { ClientPolicy => :client, UnitOfMeasurePolicy => :unit_of_measure }.each do |policy_class, factory|
    it "isolates #{factory} records and returns an empty scope without a selected organization" do
      organization = create(:organization)
      member = create(:user)
      create(:organization_membership, organization:, user: member)
      owned = create(factory, organization:)
      create(factory, organization: create(:organization))
      retired = create(factory, organization:)
      retired.update!(deleted_at: Time.current)
      policy_scope = policy_class::Scope.new(member, owned.class)

      CurrentOrganizationAccess.set(organization:) do
        expect(policy_scope.resolve).to contain_exactly(owned)
      end
      CurrentOrganizationAccess.set(organization: nil) do
        expect(policy_scope.resolve).to be_empty
      end
    end
  end
end
