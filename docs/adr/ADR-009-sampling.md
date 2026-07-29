# ADR-009 — Sampling limitado localmente

## Status

Aceito para 1.0.

## Contexto

O agente precisa controlar volume durante carga alta e aceitar redução remota sem permitir expansão inesperada da coleta.

## Decisão

Usar `sampling_rate` local como teto. Configuração remota pode somente reduzir a taxa, desabilitar tipos ou ativar kill switch. As opções são allowlisted, limitadas e nunca incluem código/regex.

## Alternativas

Sampling exclusivamente no servidor desperdiça transporte. Sampling remoto sem teto local foi rejeitado por privacidade e previsibilidade.

## Consequências positivas

O operador conserva controle e a decisão ocorre antes de HTTP/retry.

## Consequências negativas

Sampling uniforme pode perder eventos raros; análises devem considerar a taxa efetiva.
