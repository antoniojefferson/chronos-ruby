RSpec.describe Chronos::Core::DeployNormalizer do
  class UnsafeDeployValue
    def to_s
      raise "must not be called"
    end
  end

  it "builds bounded deploy metadata and removes repository credentials" do
    normalizer = described_class.new(
      snapshot(
        :environment => "production", :app_version => "1.2.3", :service_name => "billing",
        :region => "sa-east-1", :instance_id => "web-1"
      ),
      :id_generator => proc { "deploy-generated" }
    )

    result = normalizer.call(
      :revision => "abc123", :repository => "https://token@github.com/owner/repository.git",
      :actor => "release-bot"
    )

    expect(result).to include(
      "deploy_id" => "deploy-generated", "environment" => "production",
      "revision" => "abc123", "version" => "1.2.3",
      "repository" => "github.com/owner/repository.git", "actor" => "release-bot",
      "service" => "billing", "region" => "sa-east-1", "instance" => "web-1"
    )
    expect(result.to_s).not_to include("token")
  end

  it "requires an environment and at least a revision or version" do
    config = snapshot(:environment => "", :app_version => nil, :revision => nil)
    normalizer = described_class.new(config)

    expect { normalizer.call({}) }.to raise_error(ArgumentError, /environment/)
    expect do
      described_class.new(snapshot(:app_version => nil, :revision => nil)).call({})
    end.to raise_error(ArgumentError, /revision or version/)
  end

  it "does not invoke arbitrary deploy value conversion" do
    result = described_class.new(snapshot).call(:revision => "abc123", :actor => UnsafeDeployValue.new)

    expect(result["actor"]).to be_nil
  end
end
