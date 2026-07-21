#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "chronos"

config = Chronos::Configuration.new
config.project_id = "example"
config.project_key = "not-sent"
config.host = "https://chronos.invalid"
config.apm_flush_count = 10
aggregator = Chronos::Application::ApmAggregator.new(config.snapshot)

3.times do |index|
  aggregator.record(
    "request",
    {"route" => "/accounts/:id", "method" => "GET", "status" => index == 2 ? 500 : 200,
     "duration_ms" => 25.0 + index},
    "trace_id" => "trace-#{index}"
  )
end

puts aggregator.flush.inspect
