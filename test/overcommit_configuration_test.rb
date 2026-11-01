# frozen_string_literal: true

require 'yaml'

root = File.expand_path('..', __dir__)
configuration = YAML.safe_load_file(File.join(root, '.overcommit.yml'))
workflow = File.read(File.join(root, '.github/workflows/ci.yml'))

def verify(condition, description)
  abort "FAIL: #{description}" unless condition

  puts "OK: #{description}"
end

verify(configuration.dig('PreCommit', 'TrailingWhitespace', 'enabled') == true,
       'TrailingWhitespace remains enabled before commits')
%w[BundleCheck Brakeman BundlerAudit RSpec].each do |hook|
  verify(configuration.dig('PrePush', hook, 'enabled') == false,
         "#{hook} does not delay a local push")
end

verify(workflow.include?('run: bundle exec rspec'), 'the full RSpec suite runs in CI')
verify(workflow.include?('run: bin/rubocop'), 'RuboCop runs in CI')
verify(workflow.include?('run: bin/brakeman'), 'Brakeman runs in CI')
verify(workflow.include?('run: bin/bundler-audit'), 'BundlerAudit runs in CI')
verify(workflow.include?('python script/audit_i18n.py'), 'I18n audit runs in CI')

hooks_workflow = File.read(File.join(root, '.github/workflows/pre-push-hook-tests.yml'))
verify(!workflow.lines.include?("      - feature/suppliers\n"),
       'supplier pushes do not duplicate the pull-request CI run')
verify(hooks_workflow.include?("branches-ignore:\n      - feature/suppliers"),
       'supplier pushes do not duplicate the pull-request hook run')
verify(workflow.include?('github.event_name') && hooks_workflow.include?('github.event_name'),
       'different CI event types cannot cancel one another')

puts 'OK: Fast pushes preserve all full CI quality gates.'
