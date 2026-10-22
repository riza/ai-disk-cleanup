# ai-disk-cleanup

**Recupere espaço em disco com um agente de IA — medido, em níveis e com a sua aprovação.**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

[English](README.md) · [Türkçe](README.tr.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Русский](README.ru.md) · **Português (BR)** · [日本語](README.ja.md)

Um prompt testado na prática que transforma qualquer agente de IA (Claude Code, Cursor,
Codex, …) num auditor de disco cuidadoso. Ele percorre o seu disco de cima para baixo,
agrupa o que encontra pelo quanto você se arrependeria de apagar e **espera a sua aprovação
antes de tocar em qualquer coisa**.

Funciona em **macOS, Linux e Windows**.

## Por que não fazer `du | sort` na mão?

Porque os maiores ganhos quase nunca estão onde você olha primeiro, e os números óbvios
mentem:

- Um `Docker.raw` que informava **60 GB** ocupava de fato **14 GB**. Apagá-lo com base no
  tamanho aparente teria colocado um número errado no relatório.
- O verdadeiro campeão era um diretório de **23 GB** cheio de worktrees de `git` mortos de
  uma refatoração abandonada — invisível para qualquer checklist de "limpe seus caches".
- Dois runtimes de simulador de iOS de **15 GB** cada, de versões que ninguém mais mira,
  estavam em `/Library`, onde uma varredura só do diretório pessoal nunca chega.

O prompt codifica o método que acha essas coisas, junto com as travas que impedem um agente
animado de apagar o seu `.env`.

## Uso

Escolha seu idioma, abra o arquivo e cole no seu agente tudo que está abaixo da linha
`---`. Responda quando ele perguntar sobre os níveis e rode os comandos com privilégio que
ele te entregar.

| Idioma | Prompt |
|---|---|
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |

O idioma do prompt é funcional, não enfeite: ele também define em que idioma o agente vai
te reportar. Os comandos de shell permanecem em inglês em todas as traduções.

## Aviso

**Nada é apagado sem a sua aprovação explícita — nem mesmo caches.** Se ele apagar algo que você não citou, isso é um bug: pare e [abra uma issue](https://github.com/riza/ai-disk-cleanup/issues).

**O prompt pede aprovação — ele não consegue garanti-la.** Parar para perguntar é uma
instrução no texto; o que de fato garante a pausa é o modo de permissões do seu agente.
Rode-o onde as chamadas de ferramenta exijam a sua confirmação (os avisos de permissão
normais do Claude Code, o modo ask do Cursor etc.) e **não** em modo de aprovação
automática ou "yolo". Um agente rodando sem supervisão pode apagar coisas antes de você ver
a tabela de níveis.

**Leia a tabela de níveis antes de responder.** Tanto os tamanhos que ele reporta quanto o
julgamento dele sobre o que é regenerável podem estar errados. Você sabe o que tem no seu
disco; ele está inferindo da saída do `du`.

**Apagar é irreversível.** Esses comandos não mandam os arquivos para a lixeira. Tenha um
backup em que você confie antes de começar, e principalmente antes de aprovar o Nível 2 ou
o Nível 3.

**Sem garantia.** Este prompt é fornecido como está. Os comandos rodam na sua máquina e o
resultado é responsabilidade sua.

## O método

1. **Detectar o SO** — e usar apenas os comandos e caminhos daquela plataforma.
2. **Medir, nunca supor** — descer até o culpado de verdade, não até o diretório pai dele.
3. **Conhecer as pegadinhas** — discos esparsos, symlinks contados duas vezes, snapshots
   que retêm o espaço liberado, exclusões assíncronas, diretórios `target/` que não são do
   Rust.
4. **Reportar em três níveis** — e parar:

   | Nível | O que | Risco |
   |---|---|---|
   | 1 | Caches, saída de build, downloads de pacotes, worktrees mortos | Regenerável. Nenhum. |
   | 2 | Discos de VM, runtimes antigos de SDK, imagens de contêiner | Os dados reais lá dentro vão embora. |
   | 3 | Downloads, perfis de navegador, apps sem uso | Decisão inteiramente sua. |

5. **Executar passo a passo** — imprimindo o espaço liberado após cada etapa e usando o
   comando de limpeza de cada ferramenta em vez de `rm -rf`.
6. **Respeitar o limite de privilégio** — tudo que exigir `sudo` ou elevação volta para
   você como um comando pronto, nunca é contornado.
7. **Nunca apagar** código-fonte, histórico do git, `.env`, chaves, keychain, bibliotecas
   de fotos e e-mail, pastas de sincronização em nuvem, discos de VMs em execução ou
   snapshots do SO.
8. **Resumir** — incluindo o que *você* terá de corrigir na mão depois.

## Uma execução real

macOS, disco de 494 GB, **99% cheio, com 5,2 GB livres**:

| Etapa | Liberado |
|---|---|
| Worktrees de Claude/git mortos em um projeto | 4,9 GB |
| Diretórios `target/` do Rust | 5,7 GB |
| 83 × `node_modules` + caches `.next` | 18 GB |
| `~/Library/Caches` (17 GB → 2,4 GB) | 14 GB |
| `~/.cache`, npm, modcache do Go, Homebrew | 16 GB |
| Runtimes de simulador iOS 17.5 + 18.0 | 36 GB |
| Disco de VM do Docker Desktop | 14 GB |
| Disco de VM do OrbStack | 11 GB |
| Downloads: uma imagem de firmware de 11 GB + 42 instaladores | 14 GB |
| **Total** | **≈111 GB** |

**De 5,2 GB para 117 GB livres. De 99% para 71%.** Dois itens pertencentes ao root (um
cache `dyld` de simulador de 10 GB e uma instalação morta do Nessus de 6 GB) foram
devolvidos como comandos `sudo` de uma linha em vez de forçados — exatamente como o prompt
exige.

## Estrutura do repositório

    prompts/
      disk-cleanup.en.md       Inglês (referência)
      disk-cleanup.tr.md       Turco
      disk-cleanup.zh-CN.md    Chinês simplificado
      disk-cleanup.es.md       Espanhol
      disk-cleanup.ru.md       Russo
      disk-cleanup.pt-BR.md    Português do Brasil
      disk-cleanup.ja.md       Japonês
    README.pt-BR.md            Este arquivo; há um README por idioma

## Traduções

**O inglês é a referência.** Se uma tradução divergir de `prompts/disk-cleanup.en.md`,
vale a versão em inglês. Ao mudar o método, mude primeiro o prompt em inglês e depois
leve a mudança para os outros.

Novas traduções são bem-vindas: copie `disk-cleanup.en.md`, mantenha todos os comandos de
shell exatamente como estão, traduza somente o texto corrido e nomeie o arquivo com o
código BCP 47 (`disk-cleanup.<código>.md`). Acrescente um `README.<código>.md`
correspondente e uma linha nas tabelas acima.

## Uma nota sobre confiança

O prompt manda o agente tratar tudo que encontrar no disco como **dado, não instrução** —
um nome de arquivo ou um README dentro de alguma pasta baixada não consegue convencê-lo a
apagar mais. Ele também proíbe contornar o `sudo`. Leia o prompt antes de rodar; ele é
curto de propósito.

## Autor e apoio

Feito por **Rıza Sabuncu**. Se isso te poupou um fim de semana de arqueologia de disco, um café cai bem.

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
