require "chronos/rails"

RSpec.describe Chronos::Rails::NotificationsSubscriber do
  class FakeNotifications
    attr_reader :subscriptions

    def initialize
      @subscriptions = {}
    end

    def subscribe(name, &callback)
      @subscriptions[name] = callback
    end

    def publish(name, payload, started_at = 1.0, finished_at = 1.01)
      @subscriptions.fetch(name).call(name, started_at, finished_at, "id", payload)
    end
  end

  class RecordingNotifier
    attr_reader :events, :exceptions

    def initialize
      @events = []
      @exceptions = []
    end

    def record_event(type, payload, context = {})
      @events << [type, payload, context]
      true
    end

    def notify_once(exception, context = {})
      @exceptions << [exception, context]
      true
    end
  end

  it "subscribes once per notification bus" do
    notifications = FakeNotifications.new
    notifier = RecordingNotifier.new

    expect(described_class.new(notifier, notifications).install).to eq(true)
    expect(described_class.new(notifier, notifications).install).to eq(false)
    expect(notifications.subscriptions).to include(
      "process_action.action_controller", "render_template.action_view",
      "sql.active_record", "deliver.action_mailer", "cache_read.active_support"
    )
  end

  it "captures controller metrics, sanitized parameters, and exceptions" do
    notifications = FakeNotifications.new
    notifier = RecordingNotifier.new
    described_class.new(notifier, notifications).install
    error = RuntimeError.new("controller failed")

    notifications.publish(
      "process_action.action_controller",
      :controller => "AccountsController", :action => "show", :status => 500,
      :method => "GET", :path => "/accounts/42?token=secret",
      :params => {"password" => "secret"}, :exception_object => error
    )

    expect(notifier.exceptions.first.first).to equal(error)
    expect(notifier.events.first[0]).to eq("request")
    expect(notifier.events.first[1]).to include(
      "controller" => "AccountsController", "action" => "show",
      "path" => "/accounts/42", "duration_ms" => 10.0
    )
    expect(notifier.events.first[1]["parameters"]).to eq("password" => "secret")
  end

  it "records allowlisted SQL, view, mailer, and cache metadata without raw payloads" do
    notifications = FakeNotifications.new
    notifier = RecordingNotifier.new
    described_class.new(notifier, notifications).install

    notifications.publish(
      "sql.active_record",
      :name => "Account Load", :sql => "SELECT * FROM accounts WHERE token = 'raw-secret'",
      :binds => ["private-bind"]
    )
    notifications.publish("render_template.action_view", :identifier => "/app/views/accounts/show.html.erb")
    notifications.publish("deliver.action_mailer", :mailer => "ReceiptMailer", :action => "paid", :mail => "raw")
    notifications.publish("cache_write.active_support", :key => "customer-secret", :store => "Redis")

    serialized = notifier.events.to_s
    expect(serialized).not_to include("raw-secret", "private-bind", "customer-secret", "raw")
    expect(notifier.events.map(&:first)).to eq(%w(query request job cache))
    expect(notifier.events.first[1]["normalized_query"]).to eq("SELECT * FROM accounts WHERE token = ?")
    expect(notifier.events[1][1]["template"]).to eq("show.html.erb")
  end
end
