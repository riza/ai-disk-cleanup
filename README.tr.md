# ai-disk-cleanup

**Diskini neyin doldurduğunu bir AI ajanıyla bul — onaylamadığın hiçbir şeyi silmesine izin vermeden.**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

[English](README.md) · **Türkçe** · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Русский](README.ru.md) · [Português (BR)](README.pt-BR.md) · [日本語](README.ja.md)

Bir prompt ve iki küçük araç. Ajan (Claude Code, Codex, Cursor, …) macOS, Linux ya da
Windows'ta diskini ölçer, her büyük öğeyi açıklar ve her biri için sana sorar. Varsayılan
olarak **hiçbir şeyi kendisi silmez**: bir plan yazar, sen de planı her yolu yeniden
kontrol edip her öğe için y/N soran bir betikle çalıştırırsın.

Prompt yalnızca bir ricadır; ajan onu görmezden gelebilir. Bu yüzden bu depo yalnızca
prompt'a güvenmiyor. Güvenlik, silmenin nerede yapıldığından ve ajanı fiziksel olarak
engelleyen bir sandbox ya da hook'tan geliyor.

## İki mod

| | **Plan modu** (varsayılan) | **Yürütme modu** (isteğe bağlı) |
|---|---|---|
| Kim siler | Sen, `run-plan`'ı çalıştırarak | Ajan, komut başına onaylı tek öğe |
| Ajanın yazabileceği | Yalnızca `cleanup-plan.txt` | Onaylı silmeler, her biri senin teyidinle |
| Bunu ne zorlar | OS sandbox'ı (önerilir) + guard hook | Guard hook + Manual izin modu |
| Çalıştığı yer | Her ajan | macOS, Linux ya da WSL2'de Claude Code |

Bir sebebin yoksa plan modunu kullan.

## Hızlı başlangıç — plan modu

**1. Ajanı boş bir klasörde, sandbox içinde başlat.** Sandbox ajanın diskini okumasına izin
verir ama yalnızca o klasörün içine yazabilmesini işletim sistemi düzeyinde zorlar.

Claude Code (macOS, Linux, WSL2):

```bash
mkdir -p ~/disk-audit && cd ~/disk-audit
```

```bash
claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false, "failIfUnavailable": true}}'
```

Codex (macOS, Linux, WSL2 ve native Windows):

```bash
codex --sandbox workspace-write --ask-for-approval on-request
```

Claude Code'un native Windows'ta sandbox'ı yok; orada Codex'i, WSL2 içinde Claude Code'u
ya da en azından aşağıdaki guard hook'u kullan.

**2. Prompt'u kendi dilinde yapıştır:**

| Dil | Prompt |
|---|---|
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |

Prompt'un dili, ajanın sana hangi dilde cevap vereceğini de belirler.

**3. Sorularını cevapla.** Her satırda tek öğe olan numaralı bir tablo gösterir. Silinmesini
istediğin numaraları yazarsın. Ajan bunları `cleanup-plan.txt`'ye yazar.

**4. Planı oku, sonra kendin çalıştır.** Bunun için bu deponun bir klonundaki
`tools/run-plan.sh`'ı (ya da `run-plan.ps1`'i) kullan. Önce betiği oku; kısa.

```bash
bash run-plan.sh --dry-run cleanup-plan.txt
```

```bash
bash run-plan.sh cleanup-plan.txt
```

Windows'ta, normal (yönetici olmayan) bir PowerShell 7 penceresinde:

```powershell
pwsh -File run-plan.ps1 cleanup-plan.txt
```

## run-plan neleri kontrol eder

Her öğeden önce ve y dedikten sonra yeniden:

- yol mutlak ve birebir: `~`, joker karakter ya da `..` yok;
- symlink, junction ya da bulut yer tutucusu değil, hiçbir üst klasörü de değil;
- korumalı bir yer değil: sistem klasörleri, ev klasörün ve onun üst düzey klasörleri,
  anahtarlar ve keychain'ler, mail, fotoğraf kütüphaneleri, bulut senkronizasyon klasörleri;
- bir git reposunun ya da worktree'nin kökü değil;
- bir git reposunun içindeyse git-ignore edilmiş, yani kaynak kodun olamaz;
- `cmd` öğeleri tek komut; `sudo`, `rm`, pipe, zincirleme, yönlendirme,
  `git worktree remove --force` ya da `docker … --volumes` yok.

Root ya da yönetici olarak çalışmayı reddeder. Yetki gereken öğeler, kontrol edip elle
çalıştırman için en sonda listelenir. Boş cevap ya da girdinin bitmesi "hayır" demektir.

## Yürütme modu (Claude Code)

Yalnızca silmeyi ajanın kendisinin yapmasını istiyorsan. Yürütme modu sandbox'ı
kullanamaz, çünkü sandbox çalışma klasörü dışına yazmayı engeller. Bu yüzden korumayı guard
hook ve her komutu senin onaylaman sağlar.

1. Guard'ı kur:

   ```bash
   mkdir -p ~/.ai-disk-cleanup && cp guard/disk_guard.py ~/.ai-disk-cleanup/
   ```

2. [`guard/settings.example.json`](guard/settings.example.json) dosyasını inceleme
   klasörüne `.claude/settings.json` olarak koy.
3. Claude Code'u orada **Manual** izin modunda başlat (auto değil, bypass değil):

   ```bash
   AI_DISK_CLEANUP_MODE=execute claude
   ```

4. Sohbete "execute mode" yaz.

Guard her Bash ve dosya aracı çağrısından önce, her izin modunda çalışır:

- **Plan modu** (`AI_DISK_CLEANUP_MODE` tanımsız): yalnızca ölçüm komutları geçer — `du`,
  `df`, `ls`, `-delete`/`-exec` olmadan `find`, `git status`, `docker system df` ve
  benzerleri. Geri kalan her şey engellenir. Dosya araçları yalnızca çalışma klasöründeki
  `cleanup-plan*.txt`'ye yazabilir. Bunu plan modunda da kurmaya değer.
- **Yürütme modu:** ek olarak, sabit bir silme komutları kümesi (kontrol edilmiş tek bir
  yolun `rm`'si, `--force` olmadan `git worktree remove`, `npm cache clean`,
  `xcrun simctl runtime delete`, …) sana izin istemi olarak gösterilir. Manual dışındaki
  her izin modunda guard bunları reddeder; yani sen tıklamadan hiçbir şey silinmez.
- `sudo`'yu, yorumlayıcıları (`python -c`, `awk`, `bash -c`), komut ikamesini, dosyalara
  yönlendirmeyi ve çok satırlı komutları engeller. Kapalı kalacak şekilde başarısız olur:
  Python yoksa ya da guard çökerse hook 2 koduyla çıkar ve komut engellenir.

Başlamadan önce çalıştığını kontrol et: ajandan `rm -rf /tmp/probe` çalıştırmasını iste.
Guard bunu reddetmeli.

## Seni ne korur, ne korumaz

| Katman | Durdurur | Durduramaz |
|---|---|---|
| Prompt kuralları | Uyumlu bir ajanı | Onları görmezden gelen bir ajanı |
| Plan modu | Ajanın herhangi bir şeyi silmesini | Senin yanlış bir öğeyi onaylamanı |
| run-plan kontrolleri | Symlink'leri, korumalı klasörleri, repolardaki ignore edilmemiş dosyaları, `sudo`'yu, zincirlenmiş komutları | Senin evet dediğin yanlış ama geçerli bir yolu |
| OS sandbox'ı | Ajanın başlattığı herhangi bir programın klasör dışına yazmasını | Claude'un dosya araçlarını (sandbox dışında çalışırlar), MCP sunucularını; Claude Code için native Windows'u |
| Guard hook | Ölçüm dışı komutları, plan dosyası dışına yazmayı, onaylamadığın silmeleri | MCP araçlarını, PowerShell aracını, Claude Code dışındaki araçları, hook'u senin kaldırmanı |

Senin sorumluluğunda kalanlar:

- **Cevap vermeden önce tabloyu okumak.** Boyutlar ve "yeniden üretilebilir" ajanın
  yargısıdır; ikisi de yanlış olabilir.
- **Silmek kalıcıdır.** `path` öğeleri çöp kutusunu atlar. `quarantine` geri alınabilir,
  ama sen boşaltana kadar yer açmaz.
- **Yedekler.** Temizlikten önce snapshot almak en iyi güvenlik ağıdır, ama snapshot'ın
  kendisi de disk alanı tutar; tam da sende eksik olan şey.
- **Windows betiği** (`run-plan.ps1`) henüz bir Windows makinesinde çalıştırılmadı. Önce
  `-DryRun` kullan ve tuhaf bir şey görürsen bildir.

## Sorumluluk reddi

**Açıkça onaylamadığın hiçbir şey silinmez — cache bile olsa.** Adını vermediğin bir şeyi
silerse bu bir hatadır: durdur ve [issue aç](https://github.com/riza/ai-disk-cleanup/issues).

Bu proje olduğu gibi, garantisiz sunulur. Komutlar senin makinende çalışır ve sonuç senin
sorumluluğundadır.

## Kendin `du | sort` çekmek yetmez mi?

Yetmez, çünkü en büyük kazanç nadiren ilk baktığın yerdedir ve bariz sayılar yalan
söyler. Aşağıdaki turda **60 GB** görünen bir `Docker.raw` aslında **14 GB** yer
kaplıyordu; bir numaralı suçlu, yarıda bırakılmış bir refactor'dan kalan **23 GB**'lık git
worktree'leriydi; iki tane **15 GB**'lık simulator runtime'ı da ev klasörünü tarayan bir
yöntemin asla ulaşamadığı `/Library` altında duruyordu.

## Gerçek bir tur

macOS, 494 GB disk, **%99 dolu, 5.2 GB kalmış**. Bu tur, ajanın doğrudan sildiği eski bir
prompt sürümüyle yapıldı:

| Adım | Kazanç |
|---|---|
| Bir projedeki kullanılmayan git worktree'leri | 4.9 GB |
| Rust `target/` klasörleri | 5.7 GB |
| 83 × `node_modules` + `.next` cache'leri | 18 GB |
| `~/Library/Caches` (17 GB → 2.4 GB) | 14 GB |
| `~/.cache`, npm, Go modül cache'i, Homebrew | 16 GB |
| iOS 17.5 + 18.0 simulator runtime'ları | 36 GB |
| Docker Desktop VM diski | 14 GB |
| OrbStack VM diski | 11 GB |
| Downloads: 11 GB'lık firmware imajı + 42 installer | 14 GB |
| **Toplam** | **≈111 GB** |

**5.2 GB → 117 GB boş.** Bu sürümün neyi düzelttiğini de gösterdi: worktree'ler commit
edilmemiş iş kontrol edilmeden `--force` ile silindi, ve iki VM diski de motorları dururken,
içlerinde hangi volume'ların olduğuna bakılmadan silindi.

## Depo yapısı

    prompts/disk-cleanup.<dil>.md   Prompt, yedi dilde (kaynak İngilizce)
    tools/run-plan.sh               Planı macOS ve Linux'ta çalıştırır
    tools/run-plan.ps1              Planı Windows'ta çalıştırır (PowerShell 7)
    guard/disk_guard.py             Claude Code PreToolUse guard'ı
    guard/settings.example.json     İnceleme klasörü için hook ayarı
    tests/                          run-plan.sh ve guard için testler

Testleri `bash tests/test_run_plan.sh` ve `python3 tests/test_guard.py` ile çalıştır.

## Çeviriler

**İngilizce kaynaktır.** Bir çeviri `prompts/disk-cleanup.en.md` ile çelişirse İngilizce
sürüm geçerlidir. Önce İngilizce prompt'u değiştir, sonra diğerlerini. Yeni çeviriler
memnuniyetle: her komutu olduğu gibi bırak, yalnızca metni çevir ve dosyaları BCP 47
koduyla adlandır.

## Yazar & destek

**Rıza Sabuncu** tarafından yazıldı. Bir hafta sonunu disk arkeolojisinden kurtardıysa, bir kahve iyi gider.

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
