# Deploy pela CLI legada

A CLI está incluída na release legada 1.1.4 em preparação. Após sua publicação e instalação, configure pelo ambiente:

```sh
export CHRONOS_PROJECT_ID=seu-projeto
# Injete CHRONOS_PROJECT_KEY pelo mecanismo de secrets da publicação.
export CHRONOS_ENVIRONMENT=production
export CHRONOS_DEPLOY_ID=identidade-estavel-da-publicacao
export CHRONOS_DEPLOY_REVISION=revisao-do-artefato-publicado
bundle exec chronos deploy notify
```

Não é necessário copiar um script Ruby. A CLI não inicializa Rails e não lê credentials ou initializer. `CHRONOS_SERVICE_NAME` deve corresponder ao serviço do runtime. `CHRONOS_DEPLOY_VERSION` pode substituir a revisão. Host padrão: https://chronosmonitor.com.br; override: CHRONOS_HOST, somente HTTPS sem credenciais, query ou fragmento. TLS mantém a verificação existente.

Aliases: DEPLOY_ENVIRONMENT, SERVICE_NAME, DEPLOY_ID, GIT_SHA e APP_VERSION. Conflitos com ENV canônica são erros. Opções públicas explícitas prevalecem sobre ENV e `config/chronos-deploy.yml`; a chave somente entra por CHRONOS_PROJECT_KEY. YAML aceita apenas project_id, host, environment, service_name, deploy_id, revision e version, com valores string. Nunca grave secrets nesse arquivo.

`deploy diagnose --offline` exige a configuração completa de notify e verifica sua leitura local, sem autenticar credenciais. `deploy verify` usa o receipt existente, sem criar Deployment; receipt não comprova projeção. `--help` e `--version` são locais. `--timeout` aceita 0 < segundos <= 60; tentativas adicionais do transporte e backlog são desativados na CLI. O timeout limita operações do transporte e flush, não é um deadline global do processo.

Saída operacional JSON schema_version=1: success e state; erros de configuração incluem orientação estática e, quando necessário, missing_fields. Verify acrescenta verification_status do contrato de receipt. Códigos: 0 sucesso local ou entrega confirmada pela gem, 1 configuração/uso inválidos, 2 entrega não confirmada, 3 falha interna. `--on-error=warn` converte somente entrega não confirmada em status 0 e preserva success=false. Um false pode acontecer após aceite remoto; não faça retry cego. Reenvio com mesmo deploy ID pode consumir outro evento; dependências podem adicionar eventos. Não há garantia de cobrança única.

Gere integrações explicitamente:

```sh
bundle exec chronos deploy install --provider kamal --dry-run
bundle exec chronos deploy install --provider kamal
bundle exec chronos deploy install --provider kamal --check
```

Providers: kamal, capistrano, github-actions, gitlab-ci, jenkins, azure-devops. Use `--root PATH` para destino explícito. O generator `rails generate chronos:deploy:install --provider=kamal` usa o mesmo instalador. Arquivos iguais não mudam; conflitos falham. A resposta de conflito oferece a proposta de template, omitindo o conteúdo anterior por privacidade. Faça merge manual antes de considerar `--force`. Symlinks no caminho de destino são rejeitados. Nenhum pipeline é ativado automaticamente.

Kamal cria .kamal/hooks/post-deploy; Capistrano cria lib/capistrano/tasks/chronos_deploy.rake após deploy:published, localmente uma vez. Não combine com chronos/capistrano. Os quatro CI criam fragmentos em config/chronos/deploy: faça merge no job real depois da publicação bem sucedida, exportando identidade e revisão do artefato efetivamente publicado. O template GitLab é oculto e precisa ser incorporado ao job existente.

Aplicações antigas continuam usando API/receitas existentes até confirmar a capability da versão instalada. O SaaS deve selecionar a receita por faixa explícita de versões, sem remover scripts customizados. Publicação, backport e promoção dependem dos gates em docs/adr/legacy-deploy-cli.md.

Preparação de testes: [guia Docker para macOS](legacy-test-environment.md). Não é necessário instalar Rubies antigos ou alterar o Bundler global do Mac.
