#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates the documentation contract, not application behavior or module acceptance.
require 'json'
require 'pathname'

root = Pathname.new(__dir__).parent
manifest = JSON.parse((root / 'config/module_quality_registry.json').read)
modules = manifest.fetch('modules')
owners = manifest.fetch('admin_resource_owners')
index = (root / 'docs/quality/modules/README.md').read
errors = []

slugs = modules.map { |entry| entry.fetch('slug') }
errors << 'Module registry has no entries' if slugs.empty?
errors << 'Duplicate module slugs' unless slugs.uniq == slugs

allowed_kinds = %w[module embedded shared public]

modules.each do |entry|
  slug = entry.fetch('slug')
  record = entry.fetch('record')
  expected_path = "docs/quality/modules/#{slug}.md"

  errors << "Invalid module slug: #{slug}" unless slug.match?(/\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/)
  errors << "Wrong record path for #{slug}: #{record}" unless record == expected_path
  errors << "Missing module index entry: #{slug}" unless index.include?("](#{slug}.md)")
  errors << "Missing route for #{slug}" unless entry.fetch('entry_route').start_with?('/')
  errors << "Unknown module kind for #{slug}" unless allowed_kinds.include?(entry.fetch('kind'))

  file = root / record
  unless file.file?
    errors << "Missing module record: #{record}"
    next
  end

  content = file.read
  errors << "Missing scope in #{record}" unless content.include?('Alcance') || content.include?('alcance')
  errors << "Missing quality status in #{record}" unless content.match?(/NO CERRADO|CERRADO/)
  unless content.include?('PENDIENTE') || content.include?('PASÓ')
    errors << "Missing verification evidence field in #{record}"
  end
end

registered_paths = modules.map { |entry| entry.fetch('record') }
files = Dir.glob(root / 'docs/quality/modules/*.md').map { |name| Pathname.new(name).relative_path_from(root).to_s }
files.reject! { |file| file.end_with?('/README.md') }
(files - registered_paths).each { |file| errors << "Unregistered quality record: #{file}" }

routes = (root / 'config/routes.rb').read
admin_namespace = routes.split("  namespace :admin do\n", 2).last
admin_routes = admin_namespace.split("\n  end\n  resources :system_roles", 2).first
resources = admin_routes.scan(/^    resources? :([a-z_]+)/).flatten.uniq
resources.each do |resource|
  owner = owners[resource]
  errors << "Unowned admin resource: #{resource}" unless slugs.include?(owner)
end
(owners.keys - resources).each { |resource| errors << "Stale admin route ownership: #{resource}" }

if errors.any?
  warn "Module quality registry validation failed (#{errors.size}):"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Module quality registry validated: #{slugs.size} modules, #{resources.size} admin resources."
puts 'Note: This check does NOT certify RSpec, UX, security, CI, or completion of module audits.'
