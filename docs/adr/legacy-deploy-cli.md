# CLI de deploy legada — implementação para revisão

Em 31/10/2026, a branch de trabalho é `legacy/1`, baseline `a8ab679`, versão 1.1.3, Ruby >= 2.2.10 e < 2.7. A autorização para executar o plano permite desenvolver esta exceção limitada ao congelamento. A versão de lançamento foi definida como 1.1.4; sua publicação continua condicionada aos gates e ao aceite. O artefato local 1.1.3 anterior serviu somente para validação, nunca para substituir uma versão publicada.

A CLI usa OptionParser, configuração explícita e a API existente, sem boot Rails. ENV pertence à CLI. O alias Rake também não inicializa Rails. O generator Rails é somente um adaptador do instalador. Não há descoberta de revisão ou identidade por variáveis do fornecedor.

`legacy/1.2` aponta para código anterior (b2a1347), portanto não foi adotada como ref transitória. O backport deve partir de uma ref de manutenção confirmada baseada em 1.2.1; nenhuma branch foi trocada automaticamente.

A implementação atual fornece JSON em todas as respostas operacionais. O contrato desta entrega mantém a CLI leve: não oferece boot Rails; credenciais de initializer continuam atendidas pela API existente. Conflitos exibem o template proposto com o conteúdo anterior omitido por privacidade; faça merge manual ou use force explicitamente. Não gera configuração pública automaticamente. Templates de CI são fragmentos para merge manual e exigem os outputs reais exportados pelo cliente.

Gates pendentes: instalação e execução em cada Ruby legado, Rails 4.2/5.2 nos pares documentados, receipt/ledger/projeção no SaaS local, execução nos fornecedores, backport transitório e aceite de manutenção/release. A suíte standalone e o smoke do pacote foram adicionados à matriz existente; testes locais no Ruby 3.4 não comprovam suporte legado.

Revisão do contrato: diagnose exige a configuração completa de notificação, mas não autentica; host HTTPS obrigatório; metadados acima do limite do protocolo são rejeitados. Opções fora do comando correto são erros. Verify preserva verification_status do receipt, desliga dependências e nunca envia deploy. A CLI desativa retries e backlog; notify ainda pode enviar eventos de dependências. Falha no close após notify impede sucesso confirmado. Escrita usa arquivo temporário, criação exclusiva ou substituição explícita, com rechecagem de symlinks.

Preparação da matriz: [procedimento e helper Docker](../legacy-test-environment.md). Sintaxe validada com gramática Ruby 2.2 é evidência estática apenas.

Evidência local desta revisão: 201 exemplos RSpec passaram com Gemfile temporário e ferramentas locais no Ruby 3.4; 17 testes de CLI/configuração/fechamento (84 assertions), 2 testes de adaptadores (7 assertions) e 6 testes HTTPS (36 assertions) passaram. O pacote foi construído e o executável extraído respondeu help. Isso não equivale à instalação em Ruby suportado. A gramática Ruby 2.2 foi verificada estaticamente. RuboCop local 1.57 é suplementar; o gate oficial continua sendo 0.49 nas imagens legadas.

Correções da revisão de segurança: lexer SQL conservador com rejeição de entrada truncada/ambígua e validação completa antes de inspeção; sanitização de Symbol; cópia estrutural limitada antes da construção e merge de eventos; instalador POSIX baseado em descritores, usando Fiddle da biblioteca padrão para openat/mkdirat/linkat/renameat/unlinkat. Não há shell ou biblioteca nativa escolhida pelo usuário. A raiz é aberta uma vez por instalação e os descendentes são abertos sem seguir symlinks; a escrita fica ancorada aos diretórios abertos. Os testes de corrida simulam substituições entre as operações e verificam ausência de alteração em diretório externo.

Evidência após as correções de segurança: gates de core/segurança/pacote passaram em Docker Linux/amd64 nos cinco Rubies 2.2.10–2.6.10, com 221 exemplos RSpec, RuboCop 0.49.1 sem ocorrências em 225 arquivos, 25 testes adicionais de fonte (127 assertions) e 6 testes HTTPS da gem instalada (36 assertions) por runtime. Os gates Rails/Sidekiq, fornecedores, SaaS e promoção continuam separados.
