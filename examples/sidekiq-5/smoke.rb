ENV["EXPECTED_SIDEKIQ_MAJOR"] = "5"
load File.expand_path("../sidekiq-4/smoke.rb", __dir__)
