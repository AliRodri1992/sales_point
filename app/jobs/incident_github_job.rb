class IncidentGithubJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(id)
    incident = Incident.find(id)
    return if incident.github_issue_number || !Incidents::Github.configured?

    client = Incidents::Github.new
    should_create = false
    incident.with_lock do
      return if incident.github_issue_number
      if incident.github_state == 'pending'
        incident.update!(github_state: 'sending')
        should_create = true
      end
    end
    issue = should_create ? client.create(incident) : client.existing(incident.folio)
    raise IOError, 'Issue awaiting reconciliation' unless issue

    incident.update!(github_state: 'synced', github_issue_number: issue.fetch('number'), github_issue_url: issue.fetch('html_url'))
  end
end
