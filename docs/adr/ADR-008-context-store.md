# ADR-008 — Context store por runtime

## Status

Aceito para 1.0 legado.

## Contexto

Requests e jobs concorrentes não podem compartilhar usuário, parâmetros, breadcrumbs ou trace ID, mas Ruby 2.2 não oferece uma estratégia fiber-local moderna uniforme.

## Decisão

Definir uma porta de context store e usar armazenamento thread-local na linha 0.x/1.0 legado. Todo escopo restaura o valor anterior e limpa em `ensure`; somente IDs permitidos atravessam processos.

## Alternativas

Estado global foi rejeitado por vazamento entre execuções. Fiber local foi adiado para a linha moderna.

## Consequências positivas

O isolamento é testável e o núcleo não depende da primitiva concreta.

## Consequências negativas

Threads e fibers criadas pela aplicação exigem propagação explícita; adapters futuros precisam preservar a mesma porta.
