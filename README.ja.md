# ai-disk-cleanup

**AI エージェントでディスク容量を取り戻す — 測って、段階に分けて、あなたの承認を得てから。**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

[English](README.md) · [Türkçe](README.tr.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Русский](README.ru.md) · [Português (BR)](README.pt-BR.md) · **日本語**

実戦で検証済みのプロンプト。任意の AI コーディングエージェント（Claude Code、Cursor、
Codex……）を、慎重なディスク監査役に変えます。ディスクを上から下へたどり、「消したら
どれだけ後悔するか」で結果を仕分けし、**あなたが承認するまで何にも手を付けません**。

**macOS、Linux、Windows** で動作します。

## 自分で `du | sort` すれば十分では？

足りません。最大の成果は最初に見る場所にはほとんどなく、わかりやすい数字は嘘をつきます。

- **60 GB** と表示されていた `Docker.raw` は、実際には **14 GB** しか占有していませんでした。
  見かけのサイズを根拠に削除していたら、報告の数字自体が誤りになっていました。
- 本当の一番の原因は、放棄されたリファクタリングの残した **23 GB** の `git` worktree
  ディレクトリ。「キャッシュを掃除しよう」式のチェックリストには決して現れません。
- もう誰も対象にしていない OS バージョン向けの **15 GB** の iOS シミュレータ runtime が
  2 つ、`/Library` に残っていました。ホームディレクトリだけを走査する方法では届きません。

このプロンプトは、それらを見つける手順と、張り切りすぎたエージェントが `.env` を
消してしまわないための歯止めを、ひとつにまとめたものです。

## 使い方

言語を選び、ファイルを開き、`---` 線より下のすべてをエージェントに貼り付けてください。
段階について尋ねられたら答え、渡された昇格コマンドを自分で実行します。

| 言語 | プロンプト |
|---|---|
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |

プロンプトの言語は飾りではなく機能です。エージェントが報告してくる言語もこれで決まります。
シェルコマンドはどの翻訳でも英語のまま残します。

## 手順

1. **OS を判定する** — そのプラットフォームのコマンドとパスだけを使う。
2. **測る、決して推測しない** — 親ディレクトリではなく、本当の原因まで掘り下げる。
3. **落とし穴を知る** — スパースディスク、二重に数えられるシンボリックリンク、解放済み
   領域を握り続けるスナップショット、非同期削除、Rust ではない `target/` ディレクトリ。
4. **3 段階で報告し**、そこで止まる：

   | 段階 | 内容 | リスク |
   |---|---|---|
   | 1 | キャッシュ、ビルド成果物、パッケージのダウンロード、放置された worktree | 再生成可能。なし。 |
   | 2 | VM ディスク、古い SDK runtime、コンテナイメージ | 中の実データは消える。 |
   | 3 | Downloads、ブラウザのプロファイル、使っていないアプリ | 完全にあなたの判断。 |

5. **一歩ずつ実行する** — 各ステップのあとに解放された容量を表示し、`rm -rf` ではなく
   各ツール自身のクリーンアップコマンドを使う。
6. **権限の境界を尊重する** — `sudo` や昇格が必要なものは、回避せず、すぐ実行できる
   コマンドとしてあなたに返す。
7. **絶対に削除しない** — ソースコード、git の履歴、`.env`、鍵、キーチェーン、写真と
   メールのデータ、クラウド同期フォルダ、稼働中 VM のディスク、OS のスナップショット。
8. **まとめる** — 事後に**あなた**が手で直す必要があるものも含めて。

## 実際の 1 回の実行

macOS、494 GB のディスク、**使用率 99%、残り 5.2 GB**：

| ステップ | 解放 |
|---|---|
| あるプロジェクトの放置された Claude/git worktree | 4.9 GB |
| Rust の `target/` ディレクトリ | 5.7 GB |
| 83 個の `node_modules` と `.next` キャッシュ | 18 GB |
| `~/Library/Caches`（17 GB → 2.4 GB） | 14 GB |
| `~/.cache`、npm、Go の modcache、Homebrew | 16 GB |
| iOS 17.5 と 18.0 のシミュレータ runtime | 36 GB |
| Docker Desktop の VM ディスク | 14 GB |
| OrbStack の VM ディスク | 11 GB |
| Downloads：11 GB のファームウェアイメージ + インストーラ 42 個 | 14 GB |
| **合計** | **約 111 GB** |

**空き容量 5.2 GB → 117 GB、使用率 99% → 71%。** root 所有の 2 項目（10 GB の
シミュレータ `dyld` キャッシュと、使われていない 6 GB の Nessus インストール）は
強行せず、`sudo` の 1 行コマンドとして返されました。プロンプトが求めているとおりです。

## リポジトリ構成

    prompts/
      disk-cleanup.en.md       英語（基準）
      disk-cleanup.tr.md       トルコ語
      disk-cleanup.zh-CN.md    簡体字中国語
      disk-cleanup.es.md       スペイン語
      disk-cleanup.ru.md       ロシア語
      disk-cleanup.pt-BR.md    ブラジルポルトガル語
      disk-cleanup.ja.md       日本語
    README.ja.md               このファイル。言語ごとに README があります

## 翻訳について

**英語版が基準です。** 翻訳が `prompts/disk-cleanup.en.md` と食い違う場合は英語版が
優先します。手順を変えるときは、まず英語のプロンプトを変更し、その後ほかの言語へ反映して
ください。

新しい翻訳を歓迎します。`disk-cleanup.en.md` をコピーし、シェルコマンドはすべてそのまま
残し、説明文だけを翻訳して、BCP 47 のコードでファイル名を付けてください
（`disk-cleanup.<コード>.md`）。対応する `README.<コード>.md` を追加し、上の表にも 1 行
加えてください。

## 信頼についてのひとこと

このプロンプトはエージェントに対し、ディスク上で見つけたものすべてを**指示ではなくデータ**
として扱うよう指定しています。ダウンロードしたフォルダの中にあるファイル名や README が、
もっと削除するよう言いくるめることはできません。`sudo` の回避も禁じています。実行する前に
プロンプトを読んでください。短くしてあるのは、そのためです。

## 作者とサポート

**Rıza Sabuncu** が作成しました。ディスク考古学に費やす週末を救えたなら、コーヒーを一杯いただけると嬉しいです。

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
