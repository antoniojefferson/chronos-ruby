# Informações de runtime

## Problema e limite

O agente identifica o runtime necessário para diagnóstico e inventário sem varrer o ambiente, o sistema de arquivos ou conexões da aplicação. A versão 1.0 não implementa profiling nem coleta contínua de CPU/RSS.

## Fluxo e classes

`Chronos::Core::RuntimeInfo` produz engine, versão, plataforma, PID, thread opaca e hostname permitido. `DependencyReporter` adiciona versões já carregadas de Ruby, Rails, servidor, adaptador de banco e Sidekiq em um evento separado e limitado, no máximo uma vez por agente e após deploy bem-sucedido.

## Extensão, riscos e exemplo

Aplicações podem configurar versão, release, região e instância explicitamente. Hostname, IDs de processo e inventário podem ser dados pessoais ou revelar topologia; desative `dependency_reporting` quando a finalidade não justificar a coleta.

```ruby
Chronos.configure do |config|
  config.dependency_reporting = false
  config.app_version = "2026.07.29"
end
```

Veja `spec/unit/core/runtime_info_spec.rb`, `spec/unit/application/dependency_reporter_spec.rb` e `spec/integration/dependency_delivery_spec.rb`.
