# frozen_string_literal: true

require 'json'

coverage_path = File.expand_path('../coverage/.resultset.json', __dir__)
unless File.exist?(coverage_path)
  warn 'Coverage report unavailable'
  exit 0
end

reports = JSON.parse(File.read(coverage_path)).values
report = reports.first.fetch('coverage')
rows = report.filter_map do |path, data|
  values = data.fetch('lines')
  relevant = values.compact
  next if relevant.empty?

  missing_lines = values.each_index.select { |index| values[index] == 0 }.map { |index| index + 1 }
  branch_values = data.fetch('branches', {}).values.flat_map { |value| value.is_a?(Hash) ? value.values : [] }
  missing_branches = branch_values.count { |value| value.to_i.zero? }
  { path: path.delete_prefix(Dir.pwd + '/'), total: relevant.size, misses: missing_lines,
    branch_total: branch_values.size, branch_misses: missing_branches }
end

rows.sort_by! { |row| -(row[:misses].size + row[:branch_misses]) }
puts 'Coverage gaps ordered by total missing lines plus branches:'
rows.each do |row|
  next if row[:misses].empty? && row[:branch_misses].zero?

  puts "#{row[:path]} lines #{row[:total] - row[:misses].size}/#{row[:total]} " \
       "branches #{row[:branch_total] - row[:branch_misses]}/#{row[:branch_total]} " \
       "missing line numbers: #{row[:misses].first(100).join(',')}"
end
