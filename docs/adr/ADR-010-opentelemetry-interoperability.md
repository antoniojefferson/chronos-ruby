# ADR-010 — Interoperabilidade futura com OpenTelemetry

## Status

Adiado; limite aceito para 1.0 legado.

## Contexto

O Chronos precisa correlacionar trace/request sem duplicar SDKs ou impor dependências modernas a Ruby 2.2–2.6.

## Decisão

Manter IDs de correlação e portas independentes do fornecedor na 1.0. Não depender de OpenTelemetry nem instalar instrumentação global na linha legado. Uma ponte opcional será projetada na linha transitional/modern e deverá traduzir somente campos permitidos.

## Alternativas

Adicionar o SDK como dependência obrigatória foi rejeitado por incompatibilidade e overhead. Copiar spans completos foi rejeitado por cardinalidade e privacidade.

## Consequências positivas

O protocolo v1 permanece estável e aplicações legadas não recebem novas dependências.

## Consequências negativas

Não há propagação automática com ecossistemas OpenTelemetry na 1.0; integrações futuras exigirão contrato e matriz próprios.
