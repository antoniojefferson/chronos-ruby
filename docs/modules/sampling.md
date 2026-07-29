# Sampling

## Problema e limite

Sampling reduz volume de eventos sem permitir que o servidor amplie a coleta decidida localmente. Ele não substitui quotas no receptor e não deve ser usado para esconder falhas do agente.

## Fluxo e classes

`Chronos::Configuration` valida `sampling_rate` entre `0.0` e `1.0`. `Chronos::Application::RemoteConfiguration` calcula o limite efetivo, que nunca excede o valor local, e `DeliveryPipeline` decide antes do transporte. Deploys e verificações explícitas usam seus próprios caminhos síncronos e não são descartados pelo sampling comum.

## Extensão, riscos e exemplo

O gerador aleatório pode ser injetado nos objetos internos para testes determinísticos; a API pública expõe somente a taxa. Taxas baixas podem ocultar eventos raros e não garantem amostragem estatística estratificada.

```ruby
Chronos.configure do |config|
  config.sampling_rate = 0.25
  config.remote_configuration = true
end
```

O comportamento é coberto por `spec/unit/application/remote_configuration_spec.rb`, `spec/unit/application/delivery_pipeline_spec.rb` e `spec/integration/deploy_delivery_spec.rb`.
