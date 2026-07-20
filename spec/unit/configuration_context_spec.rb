RSpec.describe Chronos::Configuration, "execution context options" do
  it "validates selectable context storage and breadcrumb limits" do
    config = configuration(:context_store => Object.new, :breadcrumb_capacity => 0, :breadcrumb_max_bytes => 0)

    expect(config.validation_errors).to include(
      "context_store must be :thread_local or implement get, set, clear, and with_context"
    )
    expect(config.validation_errors).to include("breadcrumb_capacity must be a positive integer")
    expect(config.validation_errors).to include(
      "breadcrumb_max_bytes must be an integer greater than or equal to 128"
    )
  end

  it "keeps a selected compatible strategy mutable behind the immutable snapshot" do
    store = Chronos::Adapters::ThreadLocalContextStore.new
    result = snapshot(:context_store => store)

    expect(result.context_store).to equal(store)
    expect(store).not_to be_frozen
  end

  it "uses safe Rails integration defaults" do
    result = snapshot

    expect(result.rails_enabled).to eq(true)
    expect(result.rails_capture_in_console).to eq(false)
    expect(result.rails_capture_in_test).to eq(false)
    expect(result.rails_capture_user_agent).to eq(false)
  end

  it "rejects non-Boolean Rails integration switches" do
    config = configuration(:rails_enabled => "yes", :rails_capture_in_test => nil)

    expect(config.validation_errors).to include(
      "rails_enabled must be true or false", "rails_capture_in_test must be true or false"
    )
  end
end
