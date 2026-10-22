# ai-disk-cleanup

**Recupera espacio en disco con un agente de IA — medido, por niveles y con tu aprobación.**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

[English](README.md) · [Türkçe](README.tr.md) · [简体中文](README.zh-CN.md) · **Español** · [Русский](README.ru.md) · [Português (BR)](README.pt-BR.md) · [日本語](README.ja.md)

Un prompt probado en combate que convierte cualquier agente de IA (Claude Code, Cursor,
Codex, …) en un auditor de disco cuidadoso. Recorre tu disco de arriba hacia abajo, agrupa
los hallazgos según cuánto te arrepentirías de borrarlos y **espera tu aprobación antes de
tocar nada**.

Funciona en **macOS, Linux y Windows**.

## ¿Y por qué no hacer `du | sort` a mano?

Porque las mayores ganancias casi nunca están donde miras primero, y los números obvios
mienten:

- Un `Docker.raw` que informaba **60 GB** ocupaba en realidad **14 GB**. Borrarlo según el
  tamaño aparente habría sido una decisión mal fundamentada.
- El verdadero culpable principal era un directorio de **23 GB** con worktrees de `git`
  muertos de una refactorización abandonada — invisible para cualquier lista de "limpia tus
  cachés".
- Dos runtimes de simulador de iOS de **15 GB** cada uno, para versiones que ya nadie
  soporta, vivían en `/Library`, adonde no llega un escaneo del directorio personal.

El prompt codifica el método que encuentra esas cosas, junto con las barreras que evitan
que un agente entusiasta borre tu `.env`.

## Uso

Elige tu idioma, abre el archivo y pega en tu agente todo lo que está debajo de la línea
`---`. Responde cuando pregunte por los niveles y ejecuta los comandos con privilegios que
te entregue.

| Idioma | Prompt |
|---|---|
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |

El idioma del prompt es funcional, no decorativo: también fija el idioma en el que el
agente te informa. Los comandos de shell quedan en inglés en todas las traducciones.

## Aviso legal

**El prompt pide aprobación — no puede imponerla.** Detenerse a preguntar es una
instrucción del texto; lo que realmente garantiza la pausa es el modo de permisos de tu
agente. Ejecútalo donde las llamadas a herramientas requieran tu confirmación (los avisos
de permiso normales de Claude Code, el modo ask de Cursor, etc.) y **no** en un modo de
aprobación automática o "yolo". Un agente sin supervisión puede borrar cosas antes de que
hayas visto la tabla de niveles.

**Lee la tabla de niveles antes de responder.** Tanto los tamaños que informa como su
criterio sobre qué es regenerable pueden estar equivocados. Tú sabes qué hay en tu disco;
él lo está deduciendo de la salida de `du`.

**Borrar es irreversible.** Estos comandos no mueven los archivos a la papelera. Ten una
copia de seguridad en la que confíes antes de empezar, y sobre todo antes de aprobar el
Nivel 2 o el Nivel 3.

**Sin garantía.** Este prompt se ofrece tal cual. Los comandos se ejecutan en tu máquina y
el resultado es tu responsabilidad.

## El método

1. **Detectar el SO** — y usar solo los comandos y rutas de esa plataforma.
2. **Medir, nunca suponer** — bajar hasta el culpable real, no hasta su directorio padre.
3. **Conocer las trampas** — discos dispersos, enlaces simbólicos contados dos veces,
   instantáneas que retienen el espacio liberado, borrados asíncronos, directorios
   `target/` que no son de Rust.
4. **Informar en tres niveles** — y detenerse:

   | Nivel | Qué | Riesgo |
   |---|---|---|
   | 1 | Cachés, salida de compilación, descargas de paquetes, worktrees muertos | Regenerable. Ninguno. |
   | 2 | Discos de VM, runtimes de SDK antiguos, imágenes de contenedor | Los datos reales de dentro desaparecen. |
   | 3 | Downloads, perfiles de navegador, apps sin usar | Decisión totalmente tuya. |

5. **Ejecutar paso a paso** — mostrando el espacio liberado tras cada uno y usando el
   comando de limpieza propio de cada herramienta en lugar de `rm -rf`.
6. **Respetar el límite de privilegios** — todo lo que requiera `sudo` o elevación vuelve
   a ti como un comando listo para ejecutar, nunca se rodea.
7. **Nunca borrar** código fuente, historial de git, `.env`, claves, llaveros, bibliotecas
   de fotos y correo, carpetas de sincronización en la nube, discos de VM en ejecución ni
   instantáneas del SO.
8. **Resumir** — incluyendo lo que *tú* tendrás que arreglar a mano después.

## Una ejecución real

macOS, disco de 494 GB, **99% lleno con 5,2 GB libres**:

| Paso | Liberado |
|---|---|
| Worktrees de Claude/git muertos en un proyecto | 4,9 GB |
| Directorios `target/` de Rust | 5,7 GB |
| 83 × `node_modules` + cachés `.next` | 18 GB |
| `~/Library/Caches` (17 GB → 2,4 GB) | 14 GB |
| `~/.cache`, npm, modcache de Go, Homebrew | 16 GB |
| Runtimes de simulador iOS 17.5 + 18.0 | 36 GB |
| Disco de VM de Docker Desktop | 14 GB |
| Disco de VM de OrbStack | 11 GB |
| Downloads: una imagen de firmware de 11 GB + 42 instaladores | 14 GB |
| **Total** | **≈111 GB** |

**De 5,2 GB a 117 GB libres. Del 99% al 71%.** Dos elementos propiedad de root (una caché
`dyld` de simulador de 10 GB y una instalación muerta de Nessus de 6 GB) se devolvieron
como comandos `sudo` de una línea en lugar de forzarse — exactamente como exige el prompt.

## Estructura del repositorio

    prompts/
      disk-cleanup.en.md       Inglés (fuente de referencia)
      disk-cleanup.tr.md       Turco
      disk-cleanup.zh-CN.md    Chino simplificado
      disk-cleanup.es.md       Español
      disk-cleanup.ru.md       Ruso
      disk-cleanup.pt-BR.md    Portugués de Brasil
      disk-cleanup.ja.md       Japonés
    README.es.md               Este archivo; hay un README por idioma

## Traducciones

**El inglés es la fuente de referencia.** Si una traducción se desvía de
`prompts/disk-cleanup.en.md`, manda la versión inglesa. Al cambiar el método, cambia
primero el prompt en inglés y luego porta el cambio a los demás.

Se agradecen traducciones nuevas: copia `disk-cleanup.en.md`, deja todos los comandos de
shell exactamente como están, traduce solo la prosa y nombra el archivo con su código
BCP 47 (`disk-cleanup.<código>.md`). Añade un `README.<código>.md` correspondiente y una
fila a las tablas de arriba.

## Una nota sobre confianza

El prompt le indica al agente que trate todo lo que encuentre en el disco como **datos, no
instrucciones** — un nombre de archivo o un README dentro de alguna carpeta descargada no
puede convencerlo de borrar más. También prohíbe rodear `sudo`. Lee el prompt antes de
ejecutarlo; es corto a propósito.

## Autor y apoyo

Creado por **Rıza Sabuncu**. Si te ahorró un fin de semana de arqueología de disco, se agradece un café.

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
