# ai-disk-cleanup

**AI ajanıyla disk alanı geri kazanımı — ölçülmüş, kademeli ve onaylı.**

🇬🇧 [English](README.md)

Sahada denenmiş bir prompt: herhangi bir AI kodlama ajanını (Claude Code, Cursor,
Codex, …) dikkatli bir disk denetçisine çeviriyor. Diski üstten aşağı tarar, bulduğunu
"silersen ne kadar pişman olursun" eksenine göre gruplar ve **sen onaylamadan hiçbir
şeye dokunmaz.**

**macOS, Linux ve Windows** üzerinde çalışır.

## Kendin `du | sort` çekmek yetmez mi?

Yetmiyor, çünkü en büyük kazanç nadiren ilk baktığın yerde oluyor ve bariz sayılar
yalan söylüyor:

- **60 GB** görünen bir `Docker.raw` diskte aslında **14 GB** yer kaplıyordu.
  Görünen boyuta göre raporlamak kararı yanlış yöne çevirirdi.
- Gerçek bir numaralı suçlu, yarıda bırakılmış bir refactor'dan kalan **23 GB**'lık
  ölü `git` worktree klasörüydü — hiçbir "cache'lerini temizle" listesinde yok.
- Artık hedeflenmeyen iOS sürümleri için iki tane **15 GB**'lık simulator runtime'ı
  `/Library` altında duruyordu; ev dizinini tarayan hiçbir yöntem oraya ulaşmıyor.

Prompt, bunları bulan yöntemi ve hevesli bir ajanın `.env` dosyanı silmesini önleyen
korkulukları birlikte kodluyor.

## Kullanım

Dilini seç ve prompt'u ajanına yapıştır:

| | Dosya |
|---|---|
| 🇹🇷 Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| 🇬🇧 İngilizce | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |

`---` çizgisinin altındaki her şey prompt'un kendisi. Yapıştır, kademe sorusu
geldiğinde cevapla, sana verdiği yetkili komutları çalıştır.

## Yöntem

1. **İşletim sistemini tespit et** — sonra yalnızca o platformun komutlarını kullan.
2. **Ölç, tahmin etme** — üst klasörde durma, gerçek suçluya kadar in.
3. **Tuzakları bil** — sparse diskler, iki kez sayılan symlink'ler, boşalan alanı
   tutan snapshot'lar, asenkron silmeler, Rust olmayan `target/` klasörleri.
4. **Üç kademede raporla** — ve dur:

   | Kademe | Ne | Risk |
   |---|---|---|
   | 1 | Cache, build çıktısı, paket indirmeleri, ölü worktree'ler | Yeniden üretilir. Yok. |
   | 2 | VM diskleri, eski SDK runtime'ları, konteyner imajları | İçindeki gerçek veri gider. |
   | 3 | Downloads, tarayıcı profilleri, kullanılmayan uygulamalar | Tamamen senin kararın. |

5. **Adım adım uygula** — her adımdan sonra boşalan alanı yazarak ve `rm -rf` yerine
   her aracın kendi temizleme komutunu kullanarak.
6. **Yetki sınırına saygı duy** — `sudo` ya da yönetici yetkisi gereken her şey,
   etrafından dolaşılmadan, çalıştırmaya hazır komut olarak sana döner.
7. **Asla silme**: kaynak kod, git geçmişi, `.env`, anahtarlar, keychain, fotoğraf ve
   mail depoları, bulut senkronizasyon klasörleri, çalışan VM diskleri, OS snapshot'ları.
8. **Özetle** — sonrasında *senin* elle düzeltmen gerekenler dahil.

## Gerçek bir tur

macOS, 494 GB disk, **%99 dolu, 5.2 GB kalmış**:

| Adım | Kazanç |
|---|---|
| Bir projedeki ölü Claude/git worktree'leri | 4.9 GB |
| Rust `target/` klasörleri | 5.7 GB |
| 83 × `node_modules` + `.next` cache'leri | 18 GB |
| `~/Library/Caches` (17 GB → 2.4 GB) | 14 GB |
| `~/.cache`, npm, Go modcache, Homebrew | 16 GB |
| iOS 17.5 + 18.0 simulator runtime'ları | 36 GB |
| Docker Desktop VM diski | 14 GB |
| OrbStack VM diski | 11 GB |
| Downloads: 11 GB'lık firmware imajı + 42 installer | 14 GB |
| **Toplam** | **≈111 GB** |

**5.2 GB → 117 GB boş. %99 → %71.** Root sahipli iki kalem (10 GB'lık simulator
`dyld` cache'i ve ölü 6 GB'lık Nessus kurulumu) zorlanmak yerine `sudo` tek
satırlıkları olarak geri verildi — prompt tam olarak bunu şart koşuyor.

## Depo yapısı

    prompts/
      disk-cleanup.tr.md    Türkçe prompt
      disk-cleanup.en.md    İngilizce prompt
    README.tr.md            Bu dosya
    README.md               İngilizce README

## Güven üzerine bir not

Prompt, ajana diskte bulduğu her şeyi **talimat değil veri** olarak görmesini söylüyor
— indirilmiş bir klasörün içindeki dosya adı ya da README, onu daha fazla silmeye
ikna edemez. Ayrıca `sudo`'nun etrafından dolaşmayı yasaklıyor. Çalıştırmadan önce
prompt'u oku; kısa tutulmasının sebebi bu.
