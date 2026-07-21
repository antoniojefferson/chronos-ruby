RSpec.describe Chronos::Application::DependencyReporter do
  FakeDependencySpec = Struct.new(:name, :version)

  it "returns a bounded inventory once without paths or the complete bundle" do
    loaded = {
      "rack" => FakeDependencySpec.new("rack", "1.6.13"),
      "rails" => FakeDependencySpec.new("rails", "4.2.11.3"),
      "private" => FakeDependencySpec.new("private", "1.0.0")
    }
    reporter = described_class.new(
      snapshot(:dependency_reporting => true, :dependency_max_items => 2, :app_version => "release-1"),
      :loaded_specs => proc { loaded }, :constants => {"web_server" => "Puma", "database_adapter" => "PostgreSQL"}
    )

    result = reporter.call
    expect(result["dependencies"].length).to eq(2)
    expect(result).to include(
      "ruby" => a_hash_including("version" => RUBY_VERSION),
      "rails" => "4.2.11.3", "web_server" => "Puma",
      "database_adapter" => "PostgreSQL", "release" => "release-1"
    )
    expect(result.to_s).not_to include(Dir.pwd)
    expect(reporter.call).to be_nil
  end

  it "returns nil when reporting is disabled" do
    reporter = described_class.new(snapshot(:dependency_reporting => false))

    expect(reporter.call).to be_nil
  end
end
