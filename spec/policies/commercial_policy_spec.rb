# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial policies', type: :policy do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:role) { create(:system_role, :system) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, organization:, user:, system_role: role)
    CurrentOrganizationAccess.organization = organization
    CurrentOrganizationAccess.enforce_tenant = true
  end

  after { CurrentOrganizationAccess.reset }

  def grant(*codes)
    codes.each do |code|
      permission = Permission.find_by(code:) || create(:permission, code:)
      create(:system_role_permission, system_role: role, permission:)
    end
  end

  it 'denies anonymous access and configuration' do
    [PriceList, Promotion].each do |resource|
      policy = Pundit.policy!(nil, resource)
      expect(policy).not_to be_index
      expect(policy).not_to be_show
      expect(policy).not_to be_create
      expect(policy).not_to be_update
      expect(policy).not_to be_destroy
    end
  end

  it 'keeps product write rights separate from commercial management' do
    grant('products.access', 'products.index', 'products.show', 'products.create', 'products.update')

    [PriceList, Promotion].each do |resource|
      policy = Pundit.policy!(user, resource)
      expect(policy).not_to be_access
      expect(policy).not_to be_index
      expect(policy).not_to be_create
      expect(policy).not_to be_update
    end
  end

  it 'requires the matching module access for specific actions' do
    grant('price_lists.index', 'promotions.access', 'promotions.index')

    expect(PriceListPolicy.new(user, PriceList)).not_to be_index
    expect(PromotionPolicy.new(user, Promotion)).to be_index
  end

  it 'checks history and sensitive price permissions independently of regular edits' do
    list = PriceList.new(organization:)
    grant('price_lists.access', 'price_lists.show', 'price_lists.update')

    policy = PriceListPolicy.new(user, list)
    expect(policy).to be_show
    expect(policy).to be_update
    expect(policy).not_to be_history
    expect(policy).not_to be_view_margin
    expect(policy).not_to be_below_cost

    grant('price_lists.history', 'price_lists.view_margin')
    policy = PriceListPolicy.new(user, list)
    expect(policy).to be_history
    expect(policy).to be_view_margin
    expect(policy).not_to be_below_cost

    grant('price_lists.authorize_below_cost')
    expect(PriceListPolicy.new(user, list)).to be_below_cost
  end

  it 'requires distinct transition and duplication grants' do
    grant('promotions.access', 'promotions.activate', 'promotions.archive', 'promotions.duplicate')

    policy = PromotionPolicy.new(user, Promotion.new(organization:))
    expect(policy).to be_activate
    expect(policy).to be_archive
    expect(policy).to be_destroy
    expect(policy).to be_duplicate
    expect(policy).not_to be_create
    expect(policy).not_to be_pause
    expect(policy).not_to be_resume
  end

  it 'rejects a foreign record even with membership and equivalent rights there' do
    foreign = create(:organization)
    create(:organization_membership, organization: foreign, user:)
    create(:user_role, organization: foreign, user:, system_role: role)
    grant('price_lists.access', 'price_lists.show', 'price_lists.update', 'price_lists.authorize_below_cost')

    policy = PriceListPolicy.new(user, PriceList.new(organization: foreign))
    expect(policy).not_to be_show
    expect(policy).not_to be_update
    expect(policy).not_to be_below_cost
  end

  it 'checks a standalone price list in its own organization' do
    grant('price_lists.access', 'price_lists.authorize_below_cost')

    CurrentOrganizationAccess.set(organization: nil, enforce_tenant: false) do
      expect(PriceListPolicy.new(user, PriceList.new(organization:))).to be_below_cost
    end
  end
end
