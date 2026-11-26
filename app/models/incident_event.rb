class IncidentEvent < ApplicationRecord
  belongs_to :incident
  belongs_to :actor, class_name: 'User'
  validates :kind, presence: true
end
