# Monitoramento de requests

## Problema e limite

Requests Rack/Rails alimentam métricas de duração, status e breakdown com dimensões limitadas. O módulo não lê bodies, cookies, autorização ou query string bruta.

## Fluxo e classes

O middleware Rack cria contexto isolado e mede o request. Subscribers Rails enriquecem controller/action e evitam duplicação. `CaptureTelemetry` envia a observação a `ApmAggregator`; por padrão ela integra um `metric_batch`, e com APM desativado vira evento individual sanitizado.

## Extensão, riscos e exemplo

Rotas devem ser normalizadas para evitar cardinalidade por ID. Aplicações Rack podem fornecer um normalizador por meio dos campos já aceitos, sem incluir parâmetros sensíveis.

```ruby
use Chronos::Integrations::Rack::Middleware,
    :include_user_agent => false
```

Veja `spec/integration/rack_middleware_spec.rb`, `spec/integration/rack_middleware_concurrency_spec.rb` e `spec/integration/apm_aggregation_delivery_spec.rb`.
