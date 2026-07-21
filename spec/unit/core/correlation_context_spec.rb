RSpec.describe Chronos::Core::CorrelationContext do
  it "provides every bounded correlation field with explicit overrides" do
    context = described_class.new(
      snapshot(
        :app_version => "release-1", :revision => "revision-1", :deploy_id => "deploy-1",
        :environment => "production", :service_name => "billing", :region => "sa-east-1",
        :instance_id => "instance-1"
      )
    ).call("revision" => "revision-2")

    expect(context).to eq(
      "release" => "release-1", "revision" => "revision-2", "deploy_id" => "deploy-1",
      "environment" => "production", "service" => "billing", "region" => "sa-east-1",
      "instance" => "instance-1"
    )
    expect(context.frozen?).to eq(true)
  end
end
