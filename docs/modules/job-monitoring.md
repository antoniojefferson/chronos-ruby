# Monitoramento de jobs

## Problema e limite

Jobs precisam manter correlação entre enqueue e execução e registrar duração/falha sem abrir threads ou conexões por job. A versão 1.0 cobre Sidekiq 4/5 e Active Job disponível em Rails 4.2/5.2; Resque e Delayed Job permanecem fora do escopo estável.

## Fluxo e classes

O middleware Sidekiq injeta um envelope Chronos separado dos argumentos públicos. O servidor restaura contexto, mede fila/execução e deduplica exceções aninhadas. A integração Active Job usa os hooks públicos de serialização e `perform_now`. As observações seguem para `ApmAggregator` e as exceções para o notice pipeline.

## Extensão, riscos e exemplo

Adapters que substituem hooks públicos exigem testes próprios. Argumentos Sidekiq são limitados e sanitizados, mas a aplicação deve evitar segredos e dados pessoais desnecessários.

```ruby
require "chronos/sidekiq"
Sidekiq.configure_server do |config|
  config.server_middleware { |chain| chain.add Chronos::Integrations::Sidekiq::ServerMiddleware }
end
```

Veja `spec/unit/integrations/sidekiq_spec.rb`, `spec/unit/integrations/active_job_spec.rb` e `spec/integration/sidekiq_delivery_spec.rb`.
