class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  acts_as_paranoid
end
