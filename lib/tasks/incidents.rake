namespace :incidents do
  desc 'Queue pending incident issues and reconcile interrupted submissions'
  task sync: :environment do
    abort 'GitHub App is not configured' unless Incidents::Github.configured?

    Incident.where(github_issue_number: nil).find_each { |incident| IncidentGithubJob.perform_later(incident.id) }
  end
end
