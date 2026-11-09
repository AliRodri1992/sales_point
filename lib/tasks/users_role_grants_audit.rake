# frozen_string_literal: true

require 'csv'

namespace :users do
  desc 'Read-only review of legacy organization role grants (OUTPUT=tmp/user_role_grants_review.csv)'
  task audit_role_grants: :environment do
    output = ENV.fetch('OUTPUT', 'tmp/user_role_grants_review.csv')
    assignments = UserRole.where(deleted_at: nil)
    unscoped = assignments.where(organization_id: nil)
    foreign = assignments.where.not(organization_id: nil).where(<<~SQL)
      NOT EXISTS (
        SELECT 1 FROM organization_memberships memberships
        WHERE memberships.user_id = user_roles.user_id
          AND memberships.organization_id = user_roles.organization_id
          AND memberships.deleted_at IS NULL
          AND memberships.status = 'active'
      )
    SQL
    repeated = assignments.where(branch_id: nil).where.not(organization_id: nil)
                          .group(:user_id, :system_role_id)
                          .having('COUNT(DISTINCT organization_id) > 1').count

    rows = []
    unscoped.find_each do |assignment|
      rows << ['unscoped', assignment.user_id, assignment.organization_id, assignment.system_role_id]
    end
    foreign.find_each do |assignment|
      rows << ['without_active_membership', assignment.user_id, assignment.organization_id,
               assignment.system_role_id]
    end
    repeated.each_key do |user_id, role_id|
      rows << ['historic_multiorganization', user_id, nil, role_id]
    end

    FileUtils.mkdir_p(File.dirname(output))
    CSV.open(output, 'w') do |csv|
      csv << %w[issue user_id organization_id system_role_id]
      rows.each { |row| csv << row }
    end

    puts "Role-grant review written to #{output} (#{rows.length} rows)"
    puts "Unscoped: #{unscoped.count}; missing active membership: #{foreign.count}; " \
         "roles in multiple organizations: #{repeated.length}"
    puts 'Read-only task: no grants were added, removed or changed.'
  end
end
