# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Operational database indexes', type: :model do
  def index_for(table, name)
    ActiveRecord::Base.connection.indexes(table).find { |index| index.name == name }
  end

  it 'indexes the published email template version foreign key' do
    index = index_for(:email_templates, 'idx_email_templates_published_version')
    expect(index).to be_present
    expect(index.columns).to eq(['published_version_id'])
  end

  it 'supports active role and branch filtering without scanning all assignments' do
    index = index_for(:user_roles, 'idx_user_roles_active_role_branch_user')
    expect(index).to be_present
    expect(index.columns).to eq(%w[system_role_id branch_id user_id])
    expect(index.where).to include('deleted_at IS NULL')
  end

  it 'supports date-range filtering within an organization on active branches' do
    index = index_for(:branches, 'idx_branches_active_org_created_at')
    expect(index).to be_present
    expect(index.columns).to eq(%w[organization_id created_at])
    expect(index.where).to include('deleted_at IS NULL')
  end

  it 'preserves unique payment method codes while dropping the duplicate index' do
    unique_index = index_for(:sat_payment_methods, 'index_sat_payment_methods_unique')
    expect(unique_index).to be_present
    expect(unique_index.unique).to be(true)
    expect(index_for(:sat_payment_methods, 'index_sat_payment_methods_active')).to be_nil
  end

  it 'preserves unique receipt cost allocation without a second matching index' do
    unique_index = index_for(:purchase_cost_allocations, 'idx_purchase_cost_allocation_receipt_item')
    expect(unique_index).to be_present
    expect(unique_index.unique).to be(true)
    expect(index_for(:purchase_cost_allocations,
                     'index_purchase_cost_allocations_on_goods_receipt_item_id')).to be_nil
  end
end
