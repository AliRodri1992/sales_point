# frozen_string_literal: true

class OrganizationMigration < ApplicationRecord
  belongs_to :organization

  enum :volume, { under_500: 'under_500', from_500_to_5000: '500_5000', over_5000: 'over_5000' }
  enum :priority, { catalog: 'catalog', inventory: 'inventory', customers: 'customers', all: 'all' }
  enum :status, { pending: 'pending', in_progress: 'in_progress', completed: 'completed' }

  validates :volume, :priority, :status, presence: true
  validates :organization_id, uniqueness: true
end