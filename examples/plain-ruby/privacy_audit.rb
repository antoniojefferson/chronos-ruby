$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "chronos"

config = Chronos::Configuration.new
config.project_id = "local-audit"
config.project_key = "not-delivered"
config.host = "https://chronos.invalid"
config.blocklist_keys += [:medical_record]
config.hash_keys += [:customer_id]

snapshot = config.snapshot
builder = Chronos::Core::NoticeBuilder.new(snapshot)
serializer = Chronos::Core::PayloadSerializer.new(snapshot)
exception = RuntimeError.new("failed for person@example.com with Bearer local-token")
notice = builder.call(
  exception,
  :parameters => {"password" => "plain-password"},
  :user => {"customer_id" => "customer-42", "medical_record" => "private-record"}
)

puts serializer.call(notice).body
