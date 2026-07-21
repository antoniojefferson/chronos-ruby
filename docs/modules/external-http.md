# External HTTP instrumentation

Version `0.8.0.pre.1` provides an optional `Net::HTTP` wrapper loaded through `chronos/net_http`. It is disabled by default and prepended only to a connection object explicitly passed to `Chronos.instrument_net_http`; the `Net::HTTP` class and unrelated instances are unchanged.

```ruby
require "net/http"
require "chronos"

Chronos.configure do |config|
  # connection settings omitted
  config.external_http_enabled = true
  config.external_http_trace_headers = true
end

http = Net::HTTP.new("payments.example.com", 443)
http.use_ssl = true
Chronos.instrument_net_http(http)
response = http.request(Net::HTTP::Get.new("/health"))
```

The event contains a bounded lowercase host, uppercase method, response status, monotonic duration, timeout flag, connection-error flag, and error class. A request made inside a Chronos context receives `X-Chronos-Trace-ID` and `X-Chronos-Request-ID` unless the application already set those headers. Disable propagation with `external_http_trace_headers = false`.

The wrapper never reads or records the path, query string, Authorization, other request headers, request body, response headers/body, or exception message. The native streaming block is forwarded and the identical HTTP exception is re-raised. Telemetry failures are contained.

Successful and failed calls become bounded `external_http` APM groups keyed only by host and method. A call carrying a trace ID contributes its duration to the enclosing request's `external_http` breakdown. Faraday, HTTP.rb, Excon, and RestClient are outside this release.

Installation is idempotent per object. A `false` result means collection is disabled, the object is incompatible or already instrumented, or installation was contained after an internal error.
