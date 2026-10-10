# Claude & Codex Limits

macOS menü çubuğunda Codex ve Claude aboneliğinin kalan limitlerini gösteren, Swift / SwiftUI / AppKit ile yazılmış bağımsız uygulama. macOS 13 veya üzeri gerekir. DMG hem Apple Silicon hem Intel mimarilerini içerir. Arayüz Türkçedir.

## DMG ile kurulum

[Releases](https://github.com/Mermalat/AI-limitshower-for-mac/releases) bölümünden `TopBarClaudeCodexLimits-1.1.0-universal.dmg` dosyasını indir, aç ve uygulamayı **Applications / Uygulamalar** klasörüne sürükle. Uygulamayı bu klasörden aç; Dock simgesi bulunmaz, menü çubuğunda iki gösterge görünür.

Bu sürüm yerel olarak imzalanmıştır; Developer ID imzası ve Apple noter onayı içermez. Başka bir Mac’te ilk açılışta Gatekeeper uyarısı çıkabilir. Ayrıntılar ve Apple’ın resmî yönergesi [kurulum rehberinde](docs/INSTALL.md) bulunur. Codex CLI / Claude Code pakete dahil değildir; mevcut oturumların gerekir.

## Dokümantasyon

- [Kurulum, hesap bağlantıları ve sorun giderme](docs/INSTALL.md)
- [Kod yapısı, veri akışı ve sınırlamalar](docs/ARCHITECTURE.md)
- [Geliştirme, test ve DMG üretimi](docs/DEVELOPMENT.md)
- [Sürüm notları](CHANGELOG.md)
- [GPL-3.0 lisansı](LICENSE) ve [üçüncü taraf görselleri](THIRD_PARTY_NOTICES.md)

## Çalıştırma

Hazır uygulama: `build/TopBarClaudeCodexLimits.app`. Finder’dan çift tıklayabilir veya bu klasörde `./run.sh` çalıştırabilirsin. Dock simgesi yoktur; menü çubuğundaki göstergeyi tıklayarak paneli aç.

Kaynaklardan tekrar derlemek: `./build.sh`. Apple Command Line Tools (`xcode-select --install`) veya Xcode gerekir. Uygulama bu Mac’in mimarisi için derlenir ve yerel olarak imzalanır; başka Mac’lere dağıtım için noter onayı içermez.

## Gösterge

- Menü çubuğunda Codex ve Claude için iki ayrı standart gösterge bulunur; ikisinden birini tıklayarak paneli açabilirsin. Menü çubuğunda ve panelde orijinal simgeler kullanılır. Yüzdeler **kalan** kotadır. Simgeler sağlanan `codex-2.svg` ve `claude-code.svg` dosyalarından oluşturulur; SVG kaynakları ve PNG karşılıkları `Assets/` içinde saklanır.
- Menü çubuğunda kısa dönem ve haftalık genel limitlerden **en düşük kalan yüzde** görünür. İkisinden herhangi biri tükenirse o sağlayıcı için gösterge %0 olur.
- Panelde her pencere ayrı görünür. Claude verisinde varsa Sonnet ve Opus haftalık limitleri de listelenir.
- Yeşil / bakır normal, turuncu %30 ve altı, kırmızı %10 ve altı kalan kotadır.
- `—`: veri henüz okunmadı veya bağlantı kurulmadı. Eksik veri %0 kabul edilmez.
- `!`: son başarılı okuma gösteriliyor; yeni sorgu başarısız oldu. Panelde “Eski veri” ve son başarılı güncelleme saati bulunur.
- Yenilenme saatleri Mac’in yerel saat dilimindedir. Yenilenme zamanı geçince uygulama yeni veri gelmeden kotayı kendiliğinden %100 yapmaz.

Uygulama açıldığında ve ardından seçtiğin aralıkta limitleri sorgular. Panelin altındaki güncelleme yazısını tıklayarak 1–10 dakika arasında seçim yapabilirsin; varsayılan 5 dakikadır. Seçim yeniden açılışta korunur; değiştirince yeni süre o andan itibaren başlar. Yenile düğmesi en sık 30 saniyede bir çalışır. Claude HTTP 429 döndürürse en az beş dakika ve varsa daha uzun `Retry-After` süresi boyunca manuel sorgular da bekletilir. Sonuçlar yalnızca bellekte saklanır.

Panelin yüksekliği açılışta ekranın kullanılabilir alanına göre sabitlenir; limitler geldikçe pencere yukarı taşmaz. Uzun içerik kaydırılabilir ve panelin konumu ekran sınırları içinde tutulur.

## Hesap bağlantıları

**Codex:** kurulu `codex` üzerinden `app-server` başlatılır, `initialize` / `initialized` sonrasında yalnızca `account/rateLimits/read` çağrılır. Her okumadan sonra alt süreç kapatılır; konuşma, model isteği veya limit sıfırlama işlemi başlatılmaz. Önceden Codex’e ChatGPT hesabınla giriş yapmış olmalısın. API anahtarıyla çalışan hesapların abonelik limitleri bulunmayabilir.

**Claude:** ilk açılışta bağlantı kapalıdır. Panelde **Claude bağlantısını etkinleştir** düğmesini kullanarak mevcut Claude Code oturum token’ının Anthropic’in kullanım servisine gönderilmesine izin verirsin. Bu tercih macOS uygulama tercihlerine kaydedilir.

Claude bağlantısı etkin olduğunda `~/.claude/.credentials.json` (varsa `CLAUDE_CONFIG_DIR` altı) veya macOS Anahtar Zinciri’ndeki `Claude Code-credentials` öğesi yalnızca okunur. Sadece `claudeAiOauth.accessToken` kullanılır; MCP sunucularının token’ları kullanılmaz. Token yalnızca `https://api.anthropic.com/api/oauth/usage` adresine gönderilir; HTTP yönlendirmeleri takip edilmez. Token dosyaya, uygulama tercihlerine veya günlüğe yazılmaz. Yeni kimlik bilgisi oluşturulmaz; Claude’un mevcut kimlik bilgileri değiştirilmez. Gerektiğinde macOS Anahtar Zinciri erişim istemi çıkabilir.

Claude oturumu süresi dolduğunda Claude Code’u açıp oturumunu yenile; gerekirse `/login` çalıştır. Bu sürüm Claude refresh token’ını kullanmaz veya oturumu otomatik yenilemez. GUI uygulamalarının Terminal’deki ortam değişkenlerini otomatik miras almadığını unutma.

Claude kullanım uç noktası resmî olarak belgelenmiş bir genel API değildir; ileride değişebilir. HTTP 401/403, 429 ve bağlantı hataları panelde açıklanır.

## Kontroller

`./test.sh` ağ bağlantısı kullanmadan yüzde hesaplarını, Codex çoklu/tekil limit yanıtlarını, Claude zaman damgalarını, eksik/bozuk veriyi, kimlik bilgisi seçimini, süresi dolmuş oturumları ve alt süreç yanıtlarını doğrular.

`./test.sh --live-codex` ayrıca mevcut Codex hesabından canlı limitleri okur. Test çıktısında kimlik bilgileri bulunmaz.

Bu Mac’te eski `local.TopBarClaudeCodexLimits` kimliğiyle menü öğeleri görünmüyordu: aynı minimal test, farklı kimlikle ekrana yerleşirken eski kimlikle ekran dışına düşüyordu. Uygulamanın kalıcı kimliği `com.mermalat.TopBarClaudeCodexLimits` olarak düzeltildi ve her iki göstergenin ekran içindeki konumu canlı olarak doğrulandı. Bu macOS kayıt sorunu ağsız birim testleriyle yakalanamaz; arayüzde ayrıca kontrol edilmelidir.

## Başlangıç ve çıkış

Mac açıldığında otomatik başlatmak istersen Sistem Ayarları → Genel → Giriş Öğeleri ve Uzantılar → Girişte Aç bölümüne kurduğun `.app` dosyasını ekle. Çıkış için panelin sağ altındaki üç nokta menüsünü kullan. Uygulamayı kaldırmak için kurduğun `.app` dosyasını silebilirsin; hesap oturumlarına dokunmaz.

## Kaynaklar

- [OpenAI: Codex App Server — rate limits](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt)
- [Anthropic deposunda OAuth kullanım sorgusu örneği ve 429 raporu](https://github.com/anthropics/claude-code/issues/31021)

v1.0.0 için Codex ve menü çubuğu Apple Silicon Mac’te canlı doğrulandı. Claude canlı bağlantısı ve Intel Mac üzerinde çalıştırma doğrulanmadı; Claude testleri örnek yanıtları kullanır.

## Lisans

Copyright © 2026 Mermalat. Projenin özgün kaynak kodu **GNU General Public License v3.0 only (`GPL-3.0-only`)** ile lisanslanmıştır. Tam metin [LICENSE](LICENSE) dosyasındadır. Yazılım garanti verilmeden sağlanır. Marka simgeleri bu lisans kapsamında değildir; ayrıntılar [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) içindedir.

Her DMG ile birlikte aynı sürümün eksiksiz kaynakları `TopBarClaudeCodexLimits-<sürüm>-source.tar.gz` olarak dağıtılır. Arşiv, derleme ve paketleme betiklerini de içerir.
