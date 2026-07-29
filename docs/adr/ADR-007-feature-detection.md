# ADR-007 — Feature detection nas integrações

## Status

Aceito para 1.0.

## Contexto

Rails 4.2/5.2, Active Job e Sidekiq 4/5 expõem conjuntos diferentes de constantes e hooks. Comparar apenas números de versão cria falsos positivos em instalações parciais.

## Decisão

Integrações opcionais verificam a presença da biblioteca e das APIs públicas necessárias antes de instalar middleware, subscribers ou extensões. A instalação é idempotente e não exige Zeitwerk.

## Alternativas

Branches por versão e uso de APIs privadas foram rejeitados por fragilidade e custo de manutenção.

## Consequências positivas

O núcleo permanece carregável em Ruby puro e combinações validadas compartilham adapters menores.

## Consequências negativas

Cada caminho detectado exige contrato e aplicação de exemplo; uma biblioteca que imite parcialmente a API pode precisar de tratamento dedicado.
