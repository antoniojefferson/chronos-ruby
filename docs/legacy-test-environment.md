# Preparar o ambiente de testes legado no macOS

Este procedimento testa a trilha `legacy/1`. Não publica a gem nem usa credenciais reais do SaaS.

## 1. Iniciar Docker Desktop

Instale ou atualize a edição correspondente ao processador do Mac, conforme a [documentação oficial](https://docs.docker.com/desktop/setup/install/mac-install/). Abra o aplicativo e aguarde o engine iniciar:

```sh
open -a Docker
docker version
docker info
```

`docker version` precisa mostrar Client e Server. Se aparecer erro no socket ou “Cannot connect”, o engine ainda não está disponível. Confirme o contexto com `docker context ls`; selecione o contexto local do Docker Desktop caso outro contexto esteja ativo.

## 2. Entrar no repositório e executar o primeiro Ruby

```sh
cd /Users/antoniojefferson/Develop/Projects/Rails/chronos-ruby
sh script/test_legacy_docker 2.2.10
```

O helper usa linux/amd64 explicitamente para uniformizar as imagens antigas em Mac Intel e Apple Silicon. A [documentação de plataformas do Docker](https://docs.docker.com/build/building/multi-platform/) explica a emulação; ela pode ser mais lenta.

O repositório é montado somente para leitura. O helper copia os arquivos para /work no container, exclui configuração local do Bundler, .git, .aws e .env, e remove somente os lockfiles dessa cópia. Isso é necessário porque o lockfile atual do repositório foi gerado com ferramentas modernas e não corresponde ao gemspec legado. Nenhum lockfile local é alterado.

O container instala Bundler 1.17.3 e resolve as dependências do gemspec, incluindo Rake 12.3, RuboCop 0.49 e Minitest 5.10.3. O script executa a suíte existente, os testes da CLI/adaptadores/receptor HTTPS e o smoke da gem instalada. Certificado de teste é gerado temporariamente e explicitamente confiado; verificação TLS não é desligada.

## 3. Executar a matriz Ruby completa

```sh
for version in 2.2.10 2.3.8 2.4.10 2.5.9 2.6.10; do
  sh script/test_legacy_docker "$version" || break
done
```

Pare no primeiro erro e preserve o log. Uma execução interrompida não aprova os demais Rubies. Registre por imagem: versão Ruby, OpenSSL/JSON, resultado da suíte e resultado do pacote instalado.

## 4. Executar os pares Rails suportados

```sh
sh script/test_legacy_docker 2.2.10 examples/rails-4.2
sh script/test_legacy_docker 2.3.8 examples/rails-4.2
sh script/test_legacy_docker 2.5.9 examples/rails-5.2
sh script/test_legacy_docker 2.6.10 examples/rails-5.2
```

Esses comandos executam o smoke existente da aplicação e o novo smoke do generator de deploy, em diretório temporário. Eles não ampliam os pares suportados.

## 5. Tratar falhas de preparação

- Falha no pull ou acesso a rubygems.org: verificar conexão, proxy e disponibilidade do registro.
- Erro de certificado/OpenSSL nas imagens antigas: registrar imagem e mensagem, corrigir CA ou preparar imagem derivada com certificados confiáveis compatíveis. Não usar HTTP, ssl_verify=false ou mirrors sem validação TLS.
- Dependência incompatível: identificar a dependência e fixar versão compatível na definição da imagem/matriz antes de repetir. Não modernizar o gemspec legado para fazer o teste passar.
- Erro de arquitetura: confirmar execução linux/amd64 e suporte de emulação no Docker Desktop.
- Erro RuboCop/RSpec/CLI: é resultado da validação do código, não falha de instalação; corrigir antes de promover a release.

O helper prepara execuções isoladas, mas ainda não substitui imagens reproduzíveis fixadas por digest e dependências resolvidas por runtime. A aprovação final da matriz deve preservar esses registros. Depois dos gates locais, permanecem os testes SaaS de receipt/ingestão/ledger/projeção e os smokes autorizados dos fornecedores.
