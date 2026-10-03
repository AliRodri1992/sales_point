# frozen_string_literal: true

class OrganizationMigration < ApplicationRecord
  belongs_to :organization

  enum :volume, {
    small: 'under_500',
    medium: '500_5000',
    large: 'over_5000'
  }

  enum :priority, {
    catalog: 'catalog',
    inventory: 'inventory',
    customers: 'customers',
    everything: 'all'
  }

  enum :status, {
    pending: 'pending',
    in_progress: 'in_progress',
    completed: 'completed'
  }

  validates :volume, :priority, :status, presence: true
  validates :organization_id, uniqueness: true
end
