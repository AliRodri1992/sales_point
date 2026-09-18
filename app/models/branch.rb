class Branch < ApplicationRecord
  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles
end
