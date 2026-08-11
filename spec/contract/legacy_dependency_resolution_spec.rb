RSpec.describe "transitional dependency resolution" do
  it "uses tooling compatible with the supported Ruby range" do
    gemspec = Gem::Specification.load(File.expand_path("../../chronos-ruby.gemspec", __dir__))
    bundler = gemspec.development_dependencies.find { |dependency| dependency.name == "bundler" }
    rspec = gemspec.development_dependencies.find { |dependency| dependency.name == "rspec" }

    expect(bundler.requirement).to be_satisfied_by(Gem::Version.new("2.1.0"))
    expect(rspec.requirement).to be_satisfied_by(Gem::Version.new("3.13.0"))
  end
end
