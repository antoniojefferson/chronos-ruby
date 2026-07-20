# Rack integration, execution context, and breadcrumbs

Version 0.4 adds automatic capture through `Chronos::Integrations::Rack::Middleware`. The integration implements the Rack protocol directly and does not require Rack when `chronos-ruby` is loaded. Add the middleware after configuring Chronos:

```ruby
use Chronos::Integrations::Rack::Middleware,
    :include_user_agent => false
```

## Capture behavior

The middleware catches an exception raised by the downstream application, submits it asynchronously, and re-raises the same exception object. A notification or logger failure cannot replace the application failure. An `ensure` boundary clears request context in every outcome.

Captured request fields are method, normalized route, status, duration in milliseconds, request ID, optional user agent, host, query-free path, controller/action when already supplied, approximate response size from `Content-Length`, a generated or supplied trace ID, already-parsed parameters, and application-supplied user context. The final event serializer sanitizes every field before queueing.

The middleware never reads `rack.input`, copies `QUERY_STRING`, parses a body, enumerates a response body, or reads cookies and authorization headers. Parameters are collected only from already-materialized hashes at `rack.request.query_hash`, `action_dispatch.request.query_parameters`, `action_dispatch.request.path_parameters`, or the explicit `chronos.parameters` key. User context is opt-in through `chronos.user`.

Without an explicit `chronos.route` or `action_dispatch.route_uri_pattern`, numeric and UUID path segments are replaced with `:id`. This is a conservative cardinality guard, not a complete router-aware normalizer.

## Context store

`Chronos::Ports::ContextStore` defines `get`, `set`, `clear`, and `with_context`. The legacy default, `Chronos::Adapters::ThreadLocalContextStore`, isolates each thread and restores nested scopes in `ensure`. It deliberately does not propagate state into newly created threads or fibers.

A custom strategy can be selected at configuration time if it implements the complete port:

```ruby
Chronos.configure do |config|
  # credentials omitted
  config.context_store = MyContextStore.new
end
```

Application code can add scoped values. Manual notifications issued inside the block inherit them:

```ruby
Chronos.with_context(:user => {"id" => "customer-42"}) do
  Chronos.notify(error)
end
```

## Breadcrumbs

`Chronos.add_breadcrumb` records an explicit marker in the current execution buffer:

```ruby
Chronos.add_breadcrumb(
  :category => "custom",
  :message => "payment authorization started",
  :metadata => {"provider" => "example"}
)
```

Allowed categories are `custom`, `log`, `request`, `query`, `external_http`, `cache`, and `job`; an unknown value becomes `custom`. No log, SQL, body, cache, job, or external HTTP payload is captured automatically in 0.4. Metadata exists only when the application or a later integration explicitly supplies it.

The default circular buffer keeps the newest 20 entries. Each breadcrumb is normalized to JSON primitives with bounded depth, collections, strings, nodes, and serialized bytes. The entire exception payload still passes through the privacy sanitizer before it can enter the queue or retry backlog.

## Concurrency and limitations

Concurrent Rack threads receive distinct user, parameter, breadcrumb, and trace values. Context does not cross threads automatically, so applications that start their own thread must establish a new scope explicitly. Version 0.4 captures exceptions raised during the initial Rack application call; deferred failures raised only while a server enumerates a streaming response body are not intercepted.
