# Contexto de execução

## Problema e limite

O contexto relaciona uma exceção ou métrica ao request/job atual sem criar dependência do núcleo com Rack, Rails ou Sidekiq. Ele guarda somente valores delimitados e não é um repositório de estado da aplicação.

## Fluxo e classes

`Chronos::Ports::ContextStore` define `get`, `set`, `clear` e `with_context`. Na linha 1.2, `Chronos::Adapters::FiberLocalContextStore` usa storage do Fiber quando disponível e volta com segurança ao adapter thread-local. A fachada combina o contexto explícito com o escopo atual; o serializer sanitiza e limita tudo antes da fila. Rack limpa o escopo em `ensure`, enquanto Sidekiq e Active Job propagam somente `trace_id`, `span_id`, `trace_flags` e `request_id`.

## Extensão, riscos e exemplo

Um adaptador alternativo pode ser configurado quando implementar a porta completa. Ele precisa restaurar escopos aninhados e garantir limpeza após exceções. Thread local não acompanha automaticamente fibers ou threads criadas pela aplicação; nesses casos, propague somente os identificadores permitidos.

```ruby
Chronos.with_context("trace_id" => "trace-42", "request_id" => "request-7") do
  Chronos.notify(RuntimeError.new("failure"))
end
```

Os contratos estão em `spec/unit/ports/context_store_spec.rb`, `spec/unit/adapters/thread_local_context_store_spec.rb` e `spec/integration/rack_middleware_concurrency_spec.rb`.
