# Exercises controller, SQL, cache, job, mailer, view, and exception hooks.
class DiagnosticsController < ActionController::Base
  def ok
    ActiveRecord::Base.connection.execute("SELECT 1")
    Rails.cache.write("diagnostic", "ok")
    DiagnosticJob.perform_now
    DiagnosticMailer.ping.deliver_now
  end

  def fail
    raise "synthetic controller failure"
  end
end
