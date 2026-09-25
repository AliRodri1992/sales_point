# frozen_string_literal: true

class BranchNotification < Noticed::Base
  deliver_by :database

  param :branch
  param :action
end
