# frozen_string_literal: true

# Run with: bin/rails runner script/benchmarks/promotion_quote.rb PRODUCT_ID [ITERATIONS]
# Read-only benchmark. Never runs against production automatically.
require 'benchmark'

abort 'Run the benchmark in development or test only.' unless Rails.env.development? || Rails.env.test?

product = Product.find(Integer(ARGV.fetch(0)))
iterations = Integer(ARGV.fetch(1, '100'))
abort 'Iterations must be 1..1000' unless (1..1000).cover?(iterations)

durations = []
sql_queries = 0
subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  sql_queries += 1 unless %w[SCHEMA CACHE].include?(event.payload[:name])
end

begin
  iterations.times do
    elapsed = Benchmark.realtime { Products::Quote.new(product:).call }
    durations << elapsed * 1000
  end
ensure
  ActiveSupport::Notifications.unsubscribe(subscriber)
end

sorted = durations.sort
p95 = sorted[((iterations * 0.95).ceil - 1).clamp(0, sorted.size - 1)]
puts "Iterations: #{iterations}"
puts format('Mean: %.2f ms | p95: %.2f ms | SQL queries: %d', durations.sum / iterations, p95, sql_queries)
