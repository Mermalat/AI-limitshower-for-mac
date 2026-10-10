# Kurulum ve kullanım

## Gereksinimler

- macOS 13 veya üzeri, Apple Silicon (`arm64`) veya Intel (`x86_64`).
- Codex yüzdeleri için Codex CLI kurulumu ve ChatGPT hesabıyla açık oturum.
- Claude yüzdeleri için Claude Code kurulumu ve geçerli Claude oturumu.
- Limitleri yenilemek için internet bağlantısı.

Uygulama CLI araçlarını kurmaz, oturum açmaz veya hesabın parolasını istemez. API anahtarıyla çalışan Codex hesaplarında abonelik limitleri bulunmayabilir.

## DMG kurulumu

1. GitHub Releases bölümünden `TopBarClaudeCodexLimits-<sürüm>-universal.dmg` dosyasını indir.
2. DMG’yi aç, `TopBarClaudeCodexLimits.app` dosyasını yanındaki **Applications** kısayoluna sürükle.
3. Uygulamayı Uygulamalar klasöründen aç, ardından disk görüntüsünü çıkar.
4. Menü çubuğunda Codex ve Claude göstergeleri görünür. İkisinden birini tıklayarak ayrıntıları aç.

Bu sürüm ad-hoc imzalıdır; Apple Developer ID sertifikası ve noter onayı içermez. İnternetten indirilen uygulama için macOS bir uyarı gösterebilir. Kaynağına ve bütünlüğüne güvendiğinden emin olduktan sonra Apple’ın [resmî Gatekeeper yönergesini](https://support.apple.com/en-us/102445) izle. macOS’un genel güvenlik korumalarını kapatmak gerekmez.

İndirdiğin dosyanın bütünlüğünü kontrol etmek için Release’teki `SHA256SUMS.txt` dosyasını aynı klasöre indir. Terminal’de o klasörde:

```sh
shasum -a 256 TopBarClaudeCodexLimits-1.0.0-universal.dmg
```

Çıktıyı `SHA256SUMS.txt` içindeki DMG satırıyla karşılaştır. Bu kontrol aktarım hatalarını tespit eder; Developer ID imzasının yerine geçmez.

## Hesap bağlantıları

Codex göstergesi uygulama açıldığında mevcut Codex oturumunu kullanır. CLI bulunamadığında veya hesap limit verisi döndürmediğinde açıklama panelde görünür. Uygulama `/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin` ve desteklediği masaüstü uygulaması yollarını kontrol eder; rastgele PATH girdilerinde arama yapmaz.

Claude bağlantısı varsayılan olarak kapalıdır. Panelde **Claude bağlantısını etkinleştir** düğmesine basınca mevcut Claude Code OAuth token’ının yalnızca `https://api.anthropic.com/api/oauth/usage` adresine gönderilmesine izin verirsin. Token dosyaya veya günlüğe kaydedilmez. Kaynak olarak `~/.claude/.credentials.json` veya macOS Anahtar Zinciri’ndeki `Claude Code-credentials` kaydı okunur. Anahtar Zinciri kendi erişim istemini gösterebilir.

Oturum süresi dolarsa Claude Code’da oturumunu yenileyip uygulamayı tekrar yenile.

## Göstergeler

| Gösterge | Anlamı |
| --- | --- |
| `72%` | Kısa dönem ve haftalık genel kotalardan en düşük kalan oran |
| `—` | Henüz veri yok veya sağlayıcı bağlı değil |
| `72%!` | Son başarılı veriye göre kalan oran; yeni sorgu başarısız |
| Turuncu çubuk | %30 veya daha az kaldı |
| Kırmızı çubuk | %10 veya daha az kaldı |

Panelde kısa dönem, haftalık ve varsa Claude model kotaları ayrı görünür. Yenilenme saatleri yerel saat dilimindedir. Yenilenme saati geçtiğinde yeni veri okunmadan yüzde kendiliğinden yükselmez. Panelin altındaki güncelleme yazısı bir seçim menüsüdür: 1–10 dakika arasında aralık seçebilirsin. Varsayılan 5 dakikadır; seçimin yeniden açılışta korunur. Aralık değiştiğinde yeni süre o andan itibaren başlar. Manuel yenilemeler arasında en az 30 saniye gerekir.

## Sorun giderme

| Sorun | Kontrol |
| --- | --- |
| Menü çubuğunda görünmüyor | Uygulamayı Uygulamalar’dan aç; Sistem Ayarları → Menü Çubuğu içindeki uygulama iznini ve menüdeki boş alanı kontrol et. |
| Codex bulunamadı | Codex CLI’ın desteklenen yollardan birine kurulu olduğunu kontrol et. |
| Codex hesap hatası | Codex CLI oturumunu `codex login` ile kontrol et; API anahtarı yerine ChatGPT hesabı gerekir. |
| Claude bağlı değil | Panelde bağlantıyı etkinleştir. |
| Claude 401 / 403 | Claude Code’da `/login` ile oturumunu yenile; uygulama token yenilemez. |
| Claude 429 | En az beş dakika bekle; uygulama varsa daha uzun `Retry-After` süresini de dikkate alır. |
| Panel uzun | Panel içini kaydır; pencere ekranın kullanılabilir alanında tutulur. |

## Başlangıç ve kaldırma

Otomatik başlangıç için Sistem Ayarları → Genel → Giriş Öğeleri ve Uzantılar → Girişte Aç bölümüne kurulu `.app` dosyasını ekle. Uygulama bunu kendiliğinden yapmaz.

Çıkış için panelin üç nokta menüsündeki **Çıkış** seçeneğini kullan. Kaldırmak için önce uygulamayı kapat, varsa giriş öğesini kaldır ve `.app` dosyasını sil. Codex veya Claude oturumları silinmez.
