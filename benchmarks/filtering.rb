require "benchmark"
require "chronos"

config = Chronos::Configuration.new
config.project_id = "benchmark"
config.project_key = "benchmark"
config.host = "https://chronos.invalid"
config.blocklist_keys += [:medical_record]
config.hash_keys += [:customer_id]
sanitizer = Chronos::Core::Sanitizer.new(config.snapshot)
fixture = {
  "password" => "plain-password",
  "nested" => {
    "email" => "person@example.com",
    "customer_id" => "customer-42",
    "ip" => "192.168.10.42",
    "items" => Array.new(20) { |index| {"index" => index, "token" => "secret-token"} }
  }
}
iterations = Integer(ENV["ITERATIONS"] || "10000")

100.times { sanitizer.call(fixture) }
elapsed = Benchmark.realtime { iterations.times { sanitizer.call(fixture) } }

microseconds = elapsed * 1_000_000 / iterations
puts "ruby=#{RUBY_VERSION} iterations=#{iterations} " \
     "total_seconds=#{elapsed} microseconds_per_filter=#{microseconds}"
