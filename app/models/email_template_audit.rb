# frozen_string_literal: true

class EmailTemplateAudit < ApplicationRecord
  belongs_to :email_template
  belongs_to :email_template_version, optional: true
  belongs_to :organization, optional: true
  belongs_to :actor, class_name: 'User', optional: true

  validates :action, presence: true
  before_destroy { throw :abort }
end
