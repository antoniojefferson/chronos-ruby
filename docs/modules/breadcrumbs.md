# Breadcrumbs

## Problema e limite

Breadcrumbs preservam uma trilha curta do fluxo que antecedeu uma falha. Não são logs, tracing completo ou armazenamento de payloads brutos.

## Fluxo e classes

`Chronos.add_breadcrumb` normaliza a categoria e os metadados em `Chronos::Core::Breadcrumb`. `BreadcrumbBuffer` mantém um anel de capacidade fixa no context store. O `NoticeBuilder` copia a fotografia atual; sanitizer e serializer aplicam novamente limites antes da entrega.

## Extensão, riscos e exemplo

Integrações podem registrar apenas categorias conhecidas e metadados de baixa cardinalidade. Mensagens e metadados continuam sendo dados da aplicação e podem conter informação pessoal se o chamador ignorar minimização.

```ruby
Chronos.add_breadcrumb(
  :category => "custom",
  :message => "invoice queued",
  :metadata => {"provider" => "example"}
)
```

Os limites e a herança por captura são testados em `spec/unit/core/breadcrumb_spec.rb`, `spec/unit/agent_spec.rb` e nos specs de Rack.
