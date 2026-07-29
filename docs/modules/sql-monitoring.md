# Monitoramento SQL

## Problema e limite

O monitoramento SQL mede operação, tabela e duração sem transmitir SQL bruto ou binds. Sinais locais de lentidão, repetição, possível N+1, transação longa, conexão e deadlock são diagnósticos heurísticos.

## Fluxo e classes

`Rails::NotificationsSubscriber` extrai somente campos permitidos. `Core::SqlNormalizer` remove comentários e literais, limita identificadores e calcula fingerprint SHA-256. `ApmAggregator` mantém grupos e fingerprints por trace com capacidades fixas, então drena lotes pelo pipeline comum.

## Extensão, riscos e exemplo

Thresholds podem ser configurados, mas dimensões de alta cardinalidade não devem ser adicionadas. Nomes de schema, tabela e coluna ainda podem revelar domínio e precisam de avaliação LGPD.

```ruby
Chronos.configure do |config|
  config.apm_slow_query_threshold_ms = 500.0
  config.apm_n_plus_one_threshold = 5
end
```

Veja `spec/unit/core/sql_normalizer_spec.rb`, `spec/unit/application/apm_aggregator_spec.rb` e `spec/integration/rails_telemetry_delivery_spec.rb`.
