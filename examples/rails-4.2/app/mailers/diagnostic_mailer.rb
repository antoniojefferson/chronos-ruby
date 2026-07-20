# Minimal Action Mailer fixture without production recipients or content.
class DiagnosticMailer < ActionMailer::Base
  default :from => "chronos@example.test"

  def ping
    mail(:to => "operator@example.test", :subject => "Chronos diagnostic", :body => "ok")
  end
end
