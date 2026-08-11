require "chronos/rails"

RSpec.describe Chronos::Rails::ErrorReporterSubscriber do
  it "forwards an error with bounded Rails reporter metadata" do
    notifier = double("notifier")
    error = RuntimeError.new("failed")
    expect(notifier).to receive(:notify_once) do |reported, details|
      expect(reported).to equal(error)
      expect(details).to eq(:context => {"rails_error_reporter" => {
        "handled" => true, "severity" => "warning", "source" => "application",
        "component" => "AccountsController"
      }})
      true
    end

    result = described_class.new(notifier).report(
      error, :handled => true, :severity => :warning,
      :context => {:controller => "AccountsController"}, :source => "application"
    )
    expect(result).to eq(true)
  end
end
