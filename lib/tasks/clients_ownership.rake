# frozen_string_literal: true

namespace :clients do
  desc 'Report unresolved historical client ownership without exposing personal details'
  task ownership_audit: :environment do
    counts = ActiveRecord::Base.connection.select_one(<<~SQL.squish)
      WITH evidence AS (
        SELECT phoneable_id AS client_id, organization_id FROM phones
          WHERE phoneable_type = 'Client' AND organization_id IS NOT NULL
        UNION ALL
        SELECT notable_id AS client_id, organization_id FROM notes
          WHERE notable_type = 'Client' AND organization_id IS NOT NULL
      ), evidence_summary AS (
        SELECT client_id, COUNT(DISTINCT organization_id) AS organization_count
        FROM evidence GROUP BY client_id
      )
      SELECT COUNT(*) FILTER (WHERE c.organization_id IS NOT NULL) AS assigned,
             COUNT(*) FILTER (WHERE c.organization_id IS NULL) AS unassigned,
             COUNT(*) FILTER (WHERE c.organization_id IS NULL AND es.organization_count > 1) AS conflicting,
             COUNT(*) FILTER (WHERE c.organization_id IS NULL AND es.client_id IS NULL) AS no_evidence
      FROM clients c LEFT JOIN evidence_summary es ON es.client_id = c.id
    SQL

    puts 'Clientes: auditoría de propiedad por organización'
    %w[assigned unassigned conflicting no_evidence].each do |key|
      puts "#{key}: #{counts.fetch(key)}"
    end
    puts 'Los registros sin propietario no son visibles en /admin/clients.'
    puts 'No se ha modificado ningún registro.'
  end
end
