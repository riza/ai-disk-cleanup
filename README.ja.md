# ai-disk-cleanup

**ディスクを埋めているものを AI エージェントで見つける — 承認していないものは一切消させずに。**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

[English](README.md) · [Türkçe](README.tr.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Русский](README.ru.md) · [Português (BR)](README.pt-BR.md) · **日本語**

プロンプトと 2 つの小さなツールです。エージェント（Claude Code、Codex、Cursor など）が
macOS・Linux・Windows のディスクを測定し、大きな項目をひとつずつ説明して、それぞれについて
あなたに尋ねます。既定では**エージェント自身は何も削除しません**。プランを書き、あなたが
そのプランをスクリプトで実行します。スクリプトは各パスを改めて確認し、項目ごとに y/N を
尋ねます。

プロンプトはお願いにすぎず、エージェントは無視できます。だからこのリポジトリはプロンプト
だけに頼りません。安全性は「どこで削除が行われるか」と、エージェントを物理的に止める
サンドボックスや hook から生まれます。

## 2 つのモード

| | **プランモード**（既定） | **実行モード**（任意） |
|---|---|---|
| 誰が削除するか | あなた（`run-plan` を実行） | エージェント（1 コマンドにつき承認済み 1 項目） |
| エージェントが書けるもの | `cleanup-plan.txt` のみ | 承認済みの削除のみ。1 件ずつあなたが確認 |
| 何が強制するか | OS のサンドボックス（推奨）+ guard hook | guard hook + Manual 権限モード |
| 対応 | どのエージェントでも | macOS・Linux・WSL2 上の Claude Code |

特別な理由がなければプランモードを使ってください。

## クイックスタート — プランモード

**1. 空のフォルダで、サンドボックス内でエージェントを起動します。** サンドボックスは
ディスクの読み取りは許しますが、書き込みはそのフォルダ内だけに OS が制限します。

Claude Code（macOS、Linux、WSL2）：

```bash
mkdir -p ~/disk-audit && cd ~/disk-audit
```

```bash
claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false, "failIfUnavailable": true}}'
```

Codex（macOS、Linux、WSL2、ネイティブ Windows）：

```bash
codex --sandbox workspace-write --ask-for-approval on-request
```

ネイティブ Windows の Claude Code にはサンドボックスがありません。そこでは Codex か、
WSL2 内の Claude Code、少なくとも下記の guard hook を使ってください。

**2. 自分の言語のプロンプトを貼り付けます：**

| 言語 | プロンプト |
|---|---|
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |

プロンプトの言語は、エージェントが返答する言語も決めます。

**3. 質問に答えます。** 1 行に 1 項目の番号付きの表が示されます。消したい番号で答えると、
エージェントがそれを `cleanup-plan.txt` に書きます。

**4. プランを読み、自分で実行します。** このリポジトリのクローンにある
`tools/run-plan.sh`（または `run-plan.ps1`）を使います。先にスクリプトを読んでください。
短いものです。

```bash
bash run-plan.sh --dry-run cleanup-plan.txt
```

```bash
bash run-plan.sh cleanup-plan.txt
```

Windows では、通常の（管理者ではない）PowerShell 7 ウィンドウで：

```powershell
pwsh -File run-plan.ps1 cleanup-plan.txt
```

## run-plan が確認すること

各項目の前と、あなたが y と答えた後にもう一度：

- パスが文字どおりの絶対パスであること：`~`、ワイルドカード、`..` を含まない
- シンボリックリンク、ジャンクション、クラウドのプレースホルダではなく、親フォルダにも
  それがないこと
- 保護された場所ではないこと：システムフォルダ、ホームフォルダとその直下のフォルダ、鍵と
  キーチェーン、メール、写真ライブラリ、クラウド同期フォルダ
- git リポジトリや worktree のルートではないこと
- git リポジトリ内では git で ignore されていること。つまりソースコードではありえないこと
- `cmd` 項目が単一のコマンドで、`sudo`、`rm`、パイプ、連結、リダイレクト、
  `git worktree remove --force`、`docker … --volumes` を含まないこと

root や管理者権限での実行は拒否します。昇格が必要な項目は最後に表示されるので、確認した
うえで手動で実行してください。空の回答や入力の終わりは「いいえ」として扱います。

## 実行モード（Claude Code）

エージェント自身に削除させたい場合だけ使ってください。実行モードではサンドボックスを
使えません。サンドボックスは作業フォルダ外への書き込みを止めるからです。そのため、
保護は guard hook と、あなたによる各コマンドの確認になります。

1. guard をインストールします：

   ```bash
   mkdir -p ~/.ai-disk-cleanup && cp guard/disk_guard.py ~/.ai-disk-cleanup/
   ```

2. [`guard/settings.example.json`](guard/settings.example.json) を調査用フォルダに
   `.claude/settings.json` として置きます。
3. そこで **Manual** 権限モード（auto でも bypass でもなく）で Claude Code を起動します：

   ```bash
   AI_DISK_CLEANUP_MODE=execute claude
   ```

4. チャットに "execute mode" と入力します。

guard は、どの権限モードでも、Bash とファイル系ツールの呼び出しの前に毎回動きます：

- **プランモード**（`AI_DISK_CLEANUP_MODE` 未設定）：測定コマンドだけが通ります。`du`、
  `df`、`ls`、`-delete`/`-exec` なしの `find`、`git status`、`docker system df` など。
  それ以外はすべてブロックされます。ファイル系ツールが書けるのは作業フォルダの
  `cleanup-plan*.txt` だけです。プランモードでも入れておく価値があります。
- **実行モード：** 加えて、決められた削除コマンド（確認済みの 1 パスに対する `rm`、
  `--force` なしの `git worktree remove`、`npm cache clean`、`xcrun simctl runtime delete`
  など）が権限確認としてあなたに提示されます。Manual 以外の権限モードでは guard がこれらを
  拒否するので、あなたがクリックしない限り何も削除されません。
- `sudo`、インタプリタ（`python -c`、`awk`、`bash -c`）、コマンド置換、ファイルへの
  リダイレクト、複数行のコマンドをブロックします。失敗時は閉じたままです：Python がない、
  あるいは guard が落ちた場合、hook は終了コード 2 で終わり、コマンドはブロックされます。

始める前に動作を確認してください：エージェントに `rm -rf /tmp/probe` を実行させます。
guard がそれを拒否しなければなりません。

## 何があなたを守り、何が守らないか

| 層 | 止めるもの | 止めないもの |
|---|---|---|
| プロンプトのルール | 協力的なエージェント | ルールを無視するエージェント |
| プランモード | エージェントによるあらゆる削除 | あなたが誤った項目を承認すること |
| run-plan のチェック | シンボリックリンク、保護フォルダ、リポジトリ内の ignore されていないファイル、`sudo`、連結コマンド | あなたが「はい」と答えた、誤っているが有効なパス |
| OS のサンドボックス | エージェントが起動したあらゆるプログラムによるフォルダ外への書き込み | Claude のファイル系ツール（サンドボックス外で動く）、MCP サーバー、Claude Code のネイティブ Windows |
| guard hook | 測定以外のコマンド、プランファイル以外への書き込み、確認していない削除 | MCP ツール、PowerShell ツール、Claude Code 以外のツール、あなた自身による hook の削除 |

あなたの責任として残るもの：

- **答える前に表を読むこと。** サイズも「再生成可能」もエージェントの判断であり、どちらも
  間違うことがあります。
- **削除は取り消せません。** `path` 項目はゴミ箱を経由しません。`quarantine` は元に戻せますが、
  空にするまで容量は空きません。
- **バックアップ。** 掃除前のスナップショットは最良の安全網ですが、スナップショット自体も
  ディスク容量を使います。まさに足りていないものです。
- **Windows 用スクリプト**（`run-plan.ps1`）は、まだ Windows マシンで実行していません。まず
  `-DryRun` を使い、おかしな点があれば報告してください。

## 免責事項

**明示的な承認なしに削除されるものは何もありません——キャッシュであっても。** 指定していない
ものを削除した場合はバグです。実行を止めて[issue を立ててください](https://github.com/riza/ai-disk-cleanup/issues)。

このプロジェクトは現状のまま、無保証で提供されます。コマンドはあなたのマシンで実行され、
結果はあなたの責任です。

## 自分で `du | sort` すれば十分では？

足りません。最大の成果は最初に見る場所にはほとんどなく、わかりやすい数字は嘘をつくからです。
下の実行では、**60 GB** と表示された `Docker.raw` の実際の占有は **14 GB** でした。一番の
原因は、放棄されたリファクタリングが残した **23 GB** の git worktree。さらに **15 GB** の
シミュレータ runtime が 2 つ、ホームフォルダを走査するだけでは届かない `/Library` にありました。

## 実際の 1 回の実行

macOS、494 GB のディスク、**使用率 99%、残り 5.2 GB**。この実行は、エージェントが直接削除する
旧バージョンのプロンプトで行いました：

| ステップ | 解放 |
|---|---|
| あるプロジェクトの使われていない git worktree | 4.9 GB |
| Rust の `target/` フォルダ | 5.7 GB |
| 83 個の `node_modules` + `.next` キャッシュ | 18 GB |
| `~/Library/Caches`（17 GB → 2.4 GB） | 14 GB |
| `~/.cache`、npm、Go のモジュールキャッシュ、Homebrew | 16 GB |
| iOS 17.5 と 18.0 のシミュレータ runtime | 36 GB |
| Docker Desktop の VM ディスク | 14 GB |
| OrbStack の VM ディスク | 11 GB |
| Downloads：11 GB のファームウェアイメージ + インストーラ 42 個 | 14 GB |
| **合計** | **約 111 GB** |

**空き容量 5.2 GB → 117 GB。** このバージョンが何を直したかも見えました：worktree は未コミット
の作業を確認せずに `--force` で削除され、2 つの VM ディスクはエンジンが止まった状態で、中に
どのボリュームがあるか確認しないまま削除されていました。

## リポジトリ構成

    prompts/disk-cleanup.<言語>.md   プロンプト、7 言語（英語が基準）
    tools/run-plan.sh                macOS と Linux でプランを実行
    tools/run-plan.ps1               Windows でプランを実行（PowerShell 7）
    guard/disk_guard.py              Claude Code の PreToolUse guard
    guard/settings.example.json      調査用フォルダの hook 設定
    tests/                           run-plan.sh と guard のテスト

テストは `bash tests/test_run_plan.sh` と `python3 tests/test_guard.py` で実行します。

## 翻訳について

**英語版が基準です。** 翻訳が `prompts/disk-cleanup.en.md` と食い違う場合は英語版が優先します。
まず英語のプロンプトを変え、その後ほかの言語を変えてください。新しい翻訳を歓迎します。
コマンドはすべてそのまま残し、説明文だけを翻訳し、ファイル名には BCP 47 のコードを付けて
ください。

## 作者とサポート

**Rıza Sabuncu** が作成しました。ディスク考古学に費やす週末を救えたなら、コーヒーを一杯いただけると嬉しいです。

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
