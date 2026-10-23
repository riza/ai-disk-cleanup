# ai-disk-cleanup

**Descubre qué llena tu disco con un agente de IA — sin dejar que borre nada que no hayas aprobado.**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

[English](README.md) · [Türkçe](README.tr.md) · [简体中文](README.zh-CN.md) · **Español** · [Русский](README.ru.md) · [Português (BR)](README.pt-BR.md) · [日本語](README.ja.md)

Un prompt y dos herramientas pequeñas. El agente (Claude Code, Codex, Cursor, …) mide tu
disco en macOS, Linux o Windows, explica cada elemento grande y te pregunta por cada uno.
Por defecto **nunca borra nada por sí mismo**: escribe un plan, y tú lo ejecutas con un
script que vuelve a comprobar cada ruta y pregunta y/N por elemento.

Un prompt es solo una petición; un agente puede ignorarlo. Por eso este repositorio no
depende solo del prompt. La seguridad viene de dónde se borra, y de un sandbox o un hook
que bloquea físicamente al agente.

## Dos modos

| | **Modo plan** (predeterminado) | **Modo ejecución** (opcional) |
|---|---|---|
| Quién borra | Tú, ejecutando `run-plan` | El agente, un elemento aprobado por comando |
| Qué puede escribir el agente | Solo `cleanup-plan.txt` | Borrados aprobados, cada uno confirmado por ti |
| Qué lo garantiza | Sandbox del SO (recomendado) + el guard hook | El guard hook + modo de permisos Manual |
| Funciona con | Cualquier agente | Claude Code en macOS, Linux o WSL2 |

Usa el modo plan salvo que tengas un motivo para no hacerlo.

## Inicio rápido — modo plan

**1. Inicia el agente en una carpeta vacía, dentro de un sandbox.** El sandbox le permite
leer tu disco, pero el sistema operativo le impide escribir fuera de esa carpeta.

Claude Code (macOS, Linux, WSL2):

```bash
mkdir -p ~/disk-audit && cd ~/disk-audit
```

```bash
claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false, "failIfUnavailable": true}}'
```

Codex (macOS, Linux, WSL2 y Windows nativo):

```bash
codex --sandbox workspace-write --ask-for-approval on-request
```

Claude Code no tiene sandbox en Windows nativo; allí usa Codex, Claude Code dentro de WSL2
o, como mínimo, el guard hook de abajo.

**2. Pega el prompt** en tu idioma:

| Idioma | Prompt |
|---|---|
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |

El idioma del prompt también fija el idioma en el que te responde el agente.

**3. Responde a sus preguntas.** Muestra una tabla numerada, un elemento por fila. Respondes
con los números que quieres eliminar y los escribe en `cleanup-plan.txt`.

**4. Lee el plan y ejecútalo tú mismo** con `tools/run-plan.sh` (o `run-plan.ps1`) de un
clon de este repositorio. Lee antes el script; es corto.

```bash
bash run-plan.sh --dry-run cleanup-plan.txt
```

```bash
bash run-plan.sh cleanup-plan.txt
```

En Windows, en una ventana normal (no elevada) de PowerShell 7:

```powershell
pwsh -File run-plan.ps1 cleanup-plan.txt
```

## Qué comprueba run-plan

Antes de cada elemento, y otra vez después de que respondas y:

- la ruta es absoluta y literal: sin `~`, comodines ni `..`;
- no es un enlace simbólico, junction ni marcador de posición de la nube, y ninguna carpeta
  padre lo es;
- no es una ubicación protegida: carpetas del sistema, tu carpeta personal y sus carpetas de
  primer nivel, claves y llaveros, correo, bibliotecas de fotos, carpetas sincronizadas;
- no es la raíz de un repositorio ni de un worktree de git;
- dentro de un repositorio git, está ignorada por git, así que no puede ser tu código;
- los elementos `cmd` son un único comando sin `sudo`, `rm`, tuberías, encadenamiento,
  redirección, `git worktree remove --force` ni `docker … --volumes`.

Se niega a ejecutarse como root o elevado. Los elementos que necesitan elevación se muestran
al final para que los revises y los ejecutes a mano. Una respuesta vacía o el fin de la
entrada significan no.

## Modo ejecución (Claude Code)

Solo si quieres que borre el propio agente. El modo ejecución no puede usar el sandbox,
porque el sandbox bloquea escrituras fuera de la carpeta de trabajo; así que la protección
son el guard hook y tu confirmación de cada comando.

1. Instala el guard:

   ```bash
   mkdir -p ~/.ai-disk-cleanup && cp guard/disk_guard.py ~/.ai-disk-cleanup/
   ```

2. Pon [`guard/settings.example.json`](guard/settings.example.json) en la carpeta de la
   auditoría como `.claude/settings.json`.
3. Inicia Claude Code allí en modo de permisos **Manual** (no auto, no bypass):

   ```bash
   AI_DISK_CLEANUP_MODE=execute claude
   ```

4. Escribe "execute mode" en el chat.

El guard se ejecuta antes de cada llamada a Bash y a las herramientas de archivos, en
cualquier modo de permisos:

- **Modo plan** (`AI_DISK_CLEANUP_MODE` sin definir): solo pasan comandos de medición —
  `du`, `df`, `ls`, `find` sin `-delete`/`-exec`, `git status`, `docker system df` y
  similares. Todo lo demás se bloquea. Las herramientas de archivos solo pueden escribir
  `cleanup-plan*.txt` en la carpeta de trabajo. Vale la pena instalarlo también en modo plan.
- **Modo ejecución:** además, un conjunto fijo de comandos de borrado (`rm` de una ruta
  comprobada, `git worktree remove` sin `--force`, `npm cache clean`,
  `xcrun simctl runtime delete`, …) se te presenta como aviso de permiso. En cualquier modo
  de permisos que no sea Manual, el guard los rechaza, así que nada se borra sin tu clic.
- Bloquea `sudo`, intérpretes (`python -c`, `awk`, `bash -c`), sustitución de comandos,
  redirección a archivos y comandos de varias líneas. Falla cerrado: si falta Python o el
  guard se cae, el hook sale con código 2 y el comando queda bloqueado.

Comprueba que funciona antes de empezar: pide al agente que ejecute `rm -rf /tmp/probe`. El
guard debe rechazarlo.

## Qué te protege y qué no

| Capa | Detiene | No detiene |
|---|---|---|
| Reglas del prompt | Un agente que coopera | Un agente que las ignora |
| Modo plan | Que el agente borre cualquier cosa | Que apruebes un elemento equivocado |
| Comprobaciones de run-plan | Enlaces simbólicos, carpetas protegidas, archivos no ignorados en repos, `sudo`, comandos encadenados | Una ruta equivocada pero válida a la que dijiste que sí |
| Sandbox del SO | Cualquier escritura fuera de la carpeta, de cualquier programa que lance el agente | Las herramientas de archivos de Claude (corren fuera de él), servidores MCP; Windows nativo para Claude Code |
| Guard hook | Comandos que no son de medición, escrituras fuera del archivo de plan, borrados que no confirmaste | Herramientas MCP, la herramienta PowerShell, herramientas distintas de Claude Code, que tú quites el hook |

Lo que sigue siendo responsabilidad tuya:

- **Leer la tabla antes de responder.** Los tamaños y "regenerable" son el juicio del
  agente, y ambos pueden estar mal.
- **Borrar es permanente.** Los elementos `path` no pasan por la papelera. `quarantine` es
  reversible, pero no libera nada hasta que la vacíes.
- **Copias de seguridad.** Una instantánea antes de limpiar es la mejor red de seguridad,
  pero la propia instantánea ocupa espacio, justo lo que te falta.
- **El script de Windows** (`run-plan.ps1`) todavía no se ha ejecutado en una máquina
  Windows. Usa primero `-DryRun` e informa de cualquier cosa rara.

## Aviso legal

**No se borra nada sin tu aprobación explícita — ni siquiera las cachés.** Si borra algo
que no nombraste, es un error: deténlo y [abre un issue](https://github.com/riza/ai-disk-cleanup/issues).

Este proyecto se ofrece tal cual, sin garantía. Los comandos se ejecutan en tu máquina y el
resultado es tu responsabilidad.

## ¿Y por qué no `du | sort`?

Porque las mayores ganancias casi nunca están donde miras primero, y los números obvios
mienten. En la ejecución de abajo, un `Docker.raw` que mostraba **60 GB** ocupaba **14 GB**;
el mayor culpable eran **23 GB** de worktrees de git de una refactorización abandonada; y dos
runtimes de simulador de **15 GB** estaban en `/Library`, adonde un escaneo de la carpeta
personal nunca llega.

## Una ejecución real

macOS, disco de 494 GB, **99% lleno con 5,2 GB libres**. Esta ejecución usó una versión
anterior del prompt, en la que el agente borraba directamente:

| Paso | Liberado |
|---|---|
| Worktrees de git sin uso en un proyecto | 4,9 GB |
| Carpetas `target/` de Rust | 5,7 GB |
| 83 × `node_modules` + cachés `.next` | 18 GB |
| `~/Library/Caches` (17 GB → 2,4 GB) | 14 GB |
| `~/.cache`, npm, caché de módulos de Go, Homebrew | 16 GB |
| Runtimes de simulador iOS 17.5 + 18.0 | 36 GB |
| Disco de VM de Docker Desktop | 14 GB |
| Disco de VM de OrbStack | 11 GB |
| Downloads: una imagen de firmware de 11 GB + 42 instaladores | 14 GB |
| **Total** | **≈111 GB** |

**De 5,2 GB a 117 GB libres.** También mostró lo que corrige esta versión: los worktrees se
quitaron con `--force` sin comprobar si había trabajo sin confirmar, y los dos discos de VM
se borraron con sus motores detenidos, sin mirar qué volúmenes contenían.

## Estructura del repositorio

    prompts/disk-cleanup.<idioma>.md   El prompt, en siete idiomas (el inglés es la fuente)
    tools/run-plan.sh                  Ejecuta un plan en macOS y Linux
    tools/run-plan.ps1                 Ejecuta un plan en Windows (PowerShell 7)
    guard/disk_guard.py                Guard PreToolUse de Claude Code
    guard/settings.example.json        Configuración del hook para la carpeta de auditoría
    tests/                             Pruebas de run-plan.sh y del guard

Ejecuta las pruebas con `bash tests/test_run_plan.sh` y `python3 tests/test_guard.py`.

## Traducciones

**El inglés es la fuente de referencia.** Si una traducción contradice
`prompts/disk-cleanup.en.md`, manda la versión inglesa. Cambia primero el prompt en inglés y
luego los demás. Se agradecen traducciones nuevas: deja cada comando exactamente como está,
traduce solo la prosa y nombra los archivos con un código BCP 47.

## Autor y apoyo

Creado por **Rıza Sabuncu**. Si te ahorró un fin de semana de arqueología de disco, se agradece un café.

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
