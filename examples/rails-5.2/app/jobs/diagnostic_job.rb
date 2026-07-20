# Minimal inline Active Job fixture for Chronos notification capture.
class DiagnosticJob < ActiveJob::Base
  queue_as :default

  def perform
    Rails.cache.read("diagnostic")
  end
end
