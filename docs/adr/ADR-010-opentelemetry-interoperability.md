# ADR-010 — Interoperabilidade futura com OpenTelemetry

## Status

Aceito para 1.2.

## Contexto

O Chronos precisa correlacionar trace/request sem duplicar SDKs ou impor dependências modernas a Ruby 2.2–2.6.

## Decisão

Manter IDs de correlação e portas independentes do fornecedor. Na 1.2, a ponte opcional consulta somente o span atual de um SDK já carregado, traduz `trace_id`, `span_id` e flags, e nunca instala SDK, instrumentação ou exporter. IDs Chronos explícitos têm precedência; a presença de OTel deve ser usada pelas integrações para evitar spans paralelos equivalentes.

## Alternativas

Adicionar o SDK como dependência obrigatória foi rejeitado por incompatibilidade e overhead. Copiar spans completos foi rejeitado por cardinalidade e privacidade.

## Consequências positivas

O protocolo v1 permanece estável e aplicações legadas não recebem novas dependências.

## Consequências negativas

A ponte não exporta spans OTel completos nem controla exporters; consumidores que precisam desses dados continuam responsáveis pela configuração do SDK.
