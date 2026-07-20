RSpec.describe "privacy contract" do
  SENSITIVE_VALUES = [
    "plain-password",
    "secret-api-key",
    "session-cookie-value",
    "Bearer production-token",
    "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature",
    "person@example.com",
    "529.982.247-25",
    "04.252.011/0001-10",
    "4111 1111 1111 1111"
  ].freeze

  it "never emits sensitive fixture values in the final payload" do
    exception = RuntimeError.new("request failed for person@example.com with Bearer production-token")
    context = {
      :parameters => {
        "password" => SENSITIVE_VALUES[0],
        "api_key" => SENSITIVE_VALUES[1],
        "cookie" => SENSITIVE_VALUES[2],
        "jwt" => SENSITIVE_VALUES[4],
        "cpf" => SENSITIVE_VALUES[6],
        "cnpj" => SENSITIVE_VALUES[7],
        "card_number" => SENSITIVE_VALUES[8]
      },
      :user => {"email" => SENSITIVE_VALUES[5]}
    }
    notice = Chronos::Core::NoticeBuilder.new(snapshot).call(exception, context)
    body = Chronos::Core::PayloadSerializer.new(snapshot).call(notice).body

    SENSITIVE_VALUES.each { |secret| expect(body).not_to include(secret) }
  end

  it "stores only the sanitized payload in the retry backlog" do
    notice = Chronos::Core::NoticeBuilder.new(snapshot).call(
      RuntimeError.new("failed with Bearer production-token"),
      :parameters => {"password" => "plain-password"}
    )
    event = Chronos::Core::PayloadSerializer.new(snapshot).call(notice)
    backlog = Chronos::Internal::MemoryBacklog.new(1)

    expect(backlog.push(event)).to eq(true)
    stored = backlog.shift.body
    expect(stored).not_to include("production-token")
    expect(stored).not_to include("plain-password")
  end
end
