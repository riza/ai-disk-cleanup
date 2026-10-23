# ai-disk-cleanup

**Descubra o que está enchendo o seu disco com um agente de IA — sem deixar que ele apague nada que você não aprovou.**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

[English](README.md) · [Türkçe](README.tr.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Русский](README.ru.md) · **Português (BR)** · [日本語](README.ja.md)

Um prompt e duas ferramentas pequenas. O agente (Claude Code, Codex, Cursor, …) mede o seu
disco no macOS, Linux ou Windows, explica cada item grande e pergunta sobre cada um. Por
padrão ele **nunca apaga nada sozinho**: ele escreve um plano, e você roda o plano com um
script que confere cada caminho de novo e pergunta y/N por item.

Um prompt é só um pedido; o agente pode ignorá-lo. Por isso este repositório não depende só
do prompt. A segurança vem de onde a exclusão acontece, e de um sandbox ou um hook que
bloqueia o agente fisicamente.

## Dois modos

| | **Modo plano** (padrão) | **Modo execução** (opcional) |
|---|---|---|
| Quem apaga | Você, rodando `run-plan` | O agente, um item aprovado por comando |
| O que o agente pode escrever | Só `cleanup-plan.txt` | Exclusões aprovadas, cada uma confirmada por você |
| O que garante isso | Sandbox do SO (recomendado) + o guard hook | O guard hook + modo de permissão Manual |
| Funciona com | Qualquer agente | Claude Code no macOS, Linux ou WSL2 |

Use o modo plano, a menos que tenha um motivo para não usar.

## Início rápido — modo plano

**1. Inicie o agente numa pasta vazia, dentro de um sandbox.** O sandbox deixa ele ler o
seu disco, mas o sistema operacional o impede de escrever fora daquela pasta.

Claude Code (macOS, Linux, WSL2):

```bash
mkdir -p ~/disk-audit && cd ~/disk-audit
```

```bash
claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false, "failIfUnavailable": true}}'
```

Codex (macOS, Linux, WSL2 e Windows nativo):

```bash
codex --sandbox workspace-write --ask-for-approval on-request
```

O Claude Code não tem sandbox no Windows nativo; lá, use o Codex, o Claude Code dentro do
WSL2 ou, no mínimo, o guard hook abaixo.

**2. Cole o prompt** no seu idioma:

| Idioma | Prompt |
|---|---|
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |

O idioma do prompt também define em que idioma o agente te responde.

**3. Responda às perguntas dele.** Ele mostra uma tabela numerada, um item por linha. Você
responde com os números que quer remover e ele os escreve em `cleanup-plan.txt`.

**4. Leia o plano e rode você mesmo** com `tools/run-plan.sh` (ou `run-plan.ps1`) de um
clone deste repositório. Leia o script antes; ele é curto.

```bash
bash run-plan.sh --dry-run cleanup-plan.txt
```

```bash
bash run-plan.sh cleanup-plan.txt
```

No Windows, numa janela normal (não elevada) do PowerShell 7:

```powershell
pwsh -File run-plan.ps1 cleanup-plan.txt
```

## O que o run-plan confere

Antes de cada item, e de novo depois que você responde y:

- o caminho é absoluto e literal: sem `~`, curingas ou `..`;
- não é um symlink, junction ou marcador de posição da nuvem, e nenhuma pasta-pai é;
- não é um local protegido: pastas do sistema, a sua pasta pessoal e as pastas de primeiro
  nível dela, chaves e keychains, e-mail, bibliotecas de fotos, pastas sincronizadas;
- não é a raiz de um repositório ou worktree de git;
- dentro de um repositório git, ele é ignorado pelo git, então não pode ser o seu código;
- itens `cmd` são um único comando sem `sudo`, `rm`, pipes, encadeamento, redirecionamento,
  `git worktree remove --force` ou `docker … --volumes`.

Ele se recusa a rodar como root ou elevado. Itens que precisam de elevação aparecem no
final para você conferir e rodar na mão. Resposta vazia ou fim da entrada significa não.

## Modo execução (Claude Code)

Só se você quiser que o próprio agente apague. O modo execução não pode usar o sandbox,
porque o sandbox bloqueia escritas fora da pasta de trabalho; então a proteção são o guard
hook e a sua confirmação de cada comando.

1. Instale o guard:

   ```bash
   mkdir -p ~/.ai-disk-cleanup && cp guard/disk_guard.py ~/.ai-disk-cleanup/
   ```

2. Coloque [`guard/settings.example.json`](guard/settings.example.json) na pasta da
   auditoria como `.claude/settings.json`.
3. Inicie o Claude Code lá no modo de permissão **Manual** (não auto, não bypass):

   ```bash
   AI_DISK_CLEANUP_MODE=execute claude
   ```

4. Digite "execute mode" no chat.

O guard roda antes de toda chamada de Bash e das ferramentas de arquivo, em qualquer modo
de permissão:

- **Modo plano** (`AI_DISK_CLEANUP_MODE` não definida): só passam comandos de medição —
  `du`, `df`, `ls`, `find` sem `-delete`/`-exec`, `git status`, `docker system df` e
  parecidos. Todo o resto é bloqueado. As ferramentas de arquivo só podem escrever
  `cleanup-plan*.txt` na pasta de trabalho. Vale a pena instalá-lo também no modo plano.
- **Modo execução:** além disso, um conjunto fixo de comandos de exclusão (`rm` de um
  caminho conferido, `git worktree remove` sem `--force`, `npm cache clean`,
  `xcrun simctl runtime delete`, …) é mostrado a você como aviso de permissão. Em qualquer
  modo de permissão que não seja Manual, o guard os recusa, então nada é apagado sem o seu
  clique.
- Ele bloqueia `sudo`, interpretadores (`python -c`, `awk`, `bash -c`), substituição de
  comandos, redirecionamento para arquivos e comandos de várias linhas. Ele falha fechado:
  se o Python não estiver instalado ou o guard travar, o hook sai com código 2 e o comando
  é bloqueado.

Confira se funciona antes de começar: peça ao agente para rodar `rm -rf /tmp/probe`. O
guard precisa recusar.

## O que te protege e o que não

| Camada | Impede | Não impede |
|---|---|---|
| Regras do prompt | Um agente cooperativo | Um agente que as ignora |
| Modo plano | O agente apagar qualquer coisa | Você aprovar um item errado |
| Verificações do run-plan | Symlinks, pastas protegidas, arquivos não ignorados em repos, `sudo`, comandos encadeados | Um caminho errado mas válido para o qual você disse sim |
| Sandbox do SO | Qualquer escrita fora da pasta, por qualquer programa que o agente inicie | As ferramentas de arquivo do Claude (rodam fora dele), servidores MCP; Windows nativo para o Claude Code |
| Guard hook | Comandos que não são de medição, escritas fora do arquivo de plano, exclusões que você não confirmou | Ferramentas MCP, a ferramenta PowerShell, ferramentas que não sejam o Claude Code, você remover o hook |

O que continua sendo responsabilidade sua:

- **Ler a tabela antes de responder.** Os tamanhos e o "regenerável" são o julgamento do
  agente, e ambos podem estar errados.
- **Apagar é permanente.** Itens `path` não passam pela lixeira. `quarantine` é reversível,
  mas não libera nada até você esvaziar.
- **Backups.** Um snapshot antes da limpeza é a melhor rede de segurança, mas o próprio
  snapshot ocupa espaço em disco — justamente o que está faltando.
- **O script do Windows** (`run-plan.ps1`) ainda não foi rodado numa máquina Windows. Use
  `-DryRun` primeiro e reporte qualquer coisa estranha.

## Aviso

**Nada é apagado sem a sua aprovação explícita — nem mesmo caches.** Se ele apagar algo que
você não citou, isso é um bug: pare e [abra uma issue](https://github.com/riza/ai-disk-cleanup/issues).

Este projeto é fornecido como está, sem garantia. Os comandos rodam na sua máquina e o
resultado é responsabilidade sua.

## Por que não `du | sort`?

Porque os maiores ganhos quase nunca estão onde você olha primeiro, e os números óbvios
mentem. Na execução abaixo, um `Docker.raw` que mostrava **60 GB** ocupava **14 GB**; o maior
culpado eram **23 GB** de worktrees de git de uma refatoração abandonada; e dois runtimes de
simulador de **15 GB** estavam em `/Library`, onde uma varredura da pasta pessoal nunca chega.

## Uma execução real

macOS, disco de 494 GB, **99% cheio, com 5,2 GB livres**. Esta execução usou uma versão
anterior do prompt, em que o agente apagava diretamente:

| Etapa | Liberado |
|---|---|
| Worktrees de git sem uso em um projeto | 4,9 GB |
| Pastas `target/` do Rust | 5,7 GB |
| 83 × `node_modules` + caches `.next` | 18 GB |
| `~/Library/Caches` (17 GB → 2,4 GB) | 14 GB |
| `~/.cache`, npm, cache de módulos do Go, Homebrew | 16 GB |
| Runtimes de simulador iOS 17.5 + 18.0 | 36 GB |
| Disco de VM do Docker Desktop | 14 GB |
| Disco de VM do OrbStack | 11 GB |
| Downloads: uma imagem de firmware de 11 GB + 42 instaladores | 14 GB |
| **Total** | **≈111 GB** |

**De 5,2 GB para 117 GB livres.** Ela também mostrou o que esta versão corrige: os worktrees
foram removidos com `--force` sem conferir trabalho não commitado, e os dois discos de VM
foram apagados com os motores parados, sem olhar quais volumes havia neles.

## Estrutura do repositório

    prompts/disk-cleanup.<idioma>.md   O prompt, em sete idiomas (o inglês é a referência)
    tools/run-plan.sh                  Roda um plano no macOS e no Linux
    tools/run-plan.ps1                 Roda um plano no Windows (PowerShell 7)
    guard/disk_guard.py                Guard PreToolUse do Claude Code
    guard/settings.example.json        Configuração do hook para a pasta da auditoria
    tests/                             Testes do run-plan.sh e do guard

Rode os testes com `bash tests/test_run_plan.sh` e `python3 tests/test_guard.py`.

## Traduções

**O inglês é a referência.** Se uma tradução divergir de `prompts/disk-cleanup.en.md`, vale
a versão em inglês. Mude primeiro o prompt em inglês, depois os outros. Novas traduções são
bem-vindas: mantenha cada comando exatamente como está, traduza só o texto e nomeie os
arquivos com um código BCP 47.

## Autor e apoio

Feito por **Rıza Sabuncu**. Se isso te poupou um fim de semana de arqueologia de disco, um café cai bem.

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
