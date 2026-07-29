# Deploys

## Problema e limite

Deploys criam o marco temporal usado para comparar erros e desempenho antes/depois de uma release. A gem informa o evento; reconciliação e análise pertencem ao SaaS.

## Fluxo e classes

`Chronos.notify_deploy` passa atributos explícitos a `Core::DeployNormalizer`, sanitiza o evento e usa entrega síncrona com idempotência. `CorrelationContext` copia release, revision, deploy ID, ambiente, serviço, região e instância para todos os envelopes. Uma entrega bem-sucedida libera um novo snapshot de dependências.

## Extensão, riscos e exemplo

Capistrano possui hook opcional; Kamal e GitHub Actions usam comandos documentados. A gem não lê Git nem variáveis automaticamente. O retorno `false` deve ser tratado conforme a política de deploy da aplicação.

```ruby
Chronos.notify_deploy(
  :environment => "production",
  :revision => ENV["GIT_SHA"],
  :version => ENV["APP_VERSION"]
)
```

Veja `spec/unit/core/deploy_normalizer_spec.rb`, `spec/unit/integrations/capistrano_spec.rb` e `spec/integration/deploy_delivery_spec.rb`.
