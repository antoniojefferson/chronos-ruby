RSpec.describe "legacy dependency resolution" do
  it "pins transitive tools that dropped supported Ruby versions" do
    gemspec = Gem::Specification.load(File.expand_path("../../chronos-ruby.gemspec", __dir__))
    parallel = gemspec.development_dependencies.find { |dependency| dependency.name == "parallel" }
    sidekiq_gemfile = File.read(File.expand_path("../../examples/sidekiq-5/Gemfile", __dir__))

    expect(parallel.requirement.to_s).to eq("= 1.19.2")
    expect(sidekiq_gemfile).to include('gem "rack-protection", "2.2.4"')
  end
end
