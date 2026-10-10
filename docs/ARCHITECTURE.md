# Kodun yapısı

## Dosyalar

| Dosya | Sorumluluk |
| --- | --- |
| `Sources/App.swift` | Uygulama yaşam döngüsü, iki menü öğesi, SwiftUI paneli, güncelleme zamanlayıcısı |
| `Sources/Usage.swift` | Kullanım modeli, yüzde ve zaman dönüşümleri, JSON ayrıştırma ve hata metinleri |
| `Sources/Providers.swift` | Codex alt süreci, Claude kimlik bilgisi okuma ve HTTPS sorgusu |
| `Sources/PanelPlacement.swift` | Pencereyi kullanılabilir ekran alanına yerleştiren saf hesaplama |
| `Tests/main.swift` | Ağsız modeller, ayrıştırıcılar, süreç iletişimi ve panel konumu kontrolleri |
| `build.sh` | Yerel veya universal `.app` derleme, kaynak ve lisans dosyaları, imza |
| `package.sh` | Test, universal derleme, DMG, eksiksiz kaynak arşivi ve SHA-256 toplamları |

## Uygulama yaşam döngüsü

`TopBarApp.main()` bir `NSApplication` açar, `.accessory` ilkesiyle Dock simgesini gizler ve `AppDelegate` nesnesini uygulama çalıştığı sürece tutar. Aynı paket kimliğiyle ikinci kopya açılmışsa yeni kopya kapanır.

`AppDelegate.applicationDidFinishLaunching()` Codex ve Claude için iki `NSStatusItem` oluşturur. Her öğenin kalıcı `autosaveName` değeri vardır. Simgeler paket içindeki PNG dosyalarından yüklenir. `UsageStore.start()` veri okumayı ve seçilmiş dakika aralığındaki zamanlayıcıyı başlatır. `refreshMinutes` tercihi 1–10 aralığında değilse varsayılan 5 dakika kullanılır. `setRefreshMinutes()` seçimi kaydeder, önceki zamanlayıcıyı iptal eder ve yeni zamanlayıcıyı başlatır.

Menü öğelerinden birini tıklamak ortak `NSPopover` panelini açar veya kapatır. Panel bir `NSHostingController` içindeki SwiftUI `LimitsPanel` görünümüdür. Yükseklik açılışta ekran alanına göre sabitlenir; sonradan gelen veriler pencereyi büyütmek yerine kaydırılabilir içerik oluşturur. `PanelPlacement.fit()` pencereyi ekranın `visibleFrame` alanının sekiz piksel içine sığdırır. Farklı monitör başlangıç koordinatları da hesaba katılır.

## Veri modeli

`UsageWindow` bir kota penceresini temsil eder: kimlik, başlık, kullanılan yüzde ve isteğe bağlı yenilenme zamanı. Kalan oran `max(0, min(100, 100 - used))` ile hesaplanır. Görünen tam sayı en yakın değere yuvarlanır.

`UsageSnapshot` pencere listesini, abonelik türünü ve okuma zamanını tutar. Menü çubuğunun oranı genel kısa dönem ve haftalık pencerelerin minimumudur. Sonnet/Opus gibi model kotaları panelde listelenir, genel menü oranını değiştirmez.

JSON sayısı olarak boolean, sonlu olmayan değer veya negatif kullanım kabul edilmez. Eksik veri %0 yapılmaz. Tek bir geçerli pencere kaldıysa gösterilebilir; hiç geçerli pencere yoksa açıklayıcı hata döner.

## Codex akışı

`Providers.codexPath()` yalnızca kodda tanımlı kurulum yollarını kontrol eder. `Providers.codex()` kısa ömürlü bir `codex app-server` süreci açar; telemetri `analytics.enabled=false` ile kapatılır.

Sıralama: `initialize` → `initialized` → `account/rateLimits/read`. `PipeProcess` satırla ayrılan JSON yanıtlarından beklenen isteğin kimliğini seçer. Okuma `poll` ile zaman aşımına tabi tutulur; toplam bekleme varsayılan olarak 25 saniyedir. Biriktirilen yanıtın üst sınırı 1 MiB’dir. Alt süreç hata çıktısı kaydedilmez. Süreç iletişimi tamamlandığında açık dosya uçları kapanır ve kalan alt süreç sonlandırılır. Model veya konuşma isteği gönderilmez.

`UsageParser.codex()` önce `rateLimitsByLimitId.codex` alanını, ardından eski `rateLimits` biçimini destekler. `usedPercent`, `windowDurationMins`, Unix saniyesi olan `resetsAt` ve varsa `planType` okunur.

## Claude akışı

Claude sorgusu yalnızca kullanıcı bağlantıyı etkinleştirdiyse başlar. Kimlik bilgisi dosyası varsa önce dosya, yoksa `security find-generic-password` aracılığıyla Anahtar Zinciri okunur. `CLAUDE_CONFIG_DIR` tanımlıysa dosya konumu oradan türetilir; Finder’dan açılan uygulamalar Terminal ortam değişkenlerini otomatik almaz.

Yalnızca `claudeAiOauth.accessToken` kullanılır. Boş veya satır sonu içeren token reddedilir; biliniyorsa sona erme zamanı ve `user:profile` kapsamı kontrol edilir. Başka token türleri kullanılmaz.

İstek sabit HTTPS adresine `Authorization: Bearer` ve Anthropic beta başlığıyla gönderilir. `URLSessionConfiguration.ephemeral` kullanılır; disk önbelleği ve çerez deposu kapalıdır. `NoRedirect` HTTP yönlendirmelerini reddeder. TLS doğrulaması macOS’un varsayılan davranışıdır. İstek/yanıt zaman aşımı 20/25 saniyedir.

`UsageParser.claude()` `utilization` alanını doğrudan yüzde kabul eder; kesir olarak tekrar çarpmaz. ISO 8601 zaman damgaları kesirli saniyeyle veya kesirsiz okunur. 401/403 oturum hatasıdır. 429 için sonraki sorgu en az 300 saniye ertelenir; sayısal `Retry-After` daha uzunsa o süre kullanılır. HTTP-tarihi biçimindeki `Retry-After` bu sürümde ayrıştırılmaz.

## Eşzamanlılık ve veri saklama

`UsageStore` ana aktörde çalışır ve `@Published` alanlarla paneli günceller. Sağlayıcı işleri `Task.detached(priority: .utility)` ile arka plana alınır. Her sağlayıcı için yükleniyor bayrağı yinelenen sorguyu engeller. Manuel yenilemenin 30 saniyelik sınırı otomatik zamanlayıcıdan ayrıdır.

Son başarılı anlık görüntü ve hata bellekte tutulur. Yeni okuma başarısız olursa eski görüntü korunur ve `!` / **Eski veri** olarak işaretlenir.

`UserDefaults` Claude bağlantı tercihini ve otomatik güncelleme aralığını tutar; AppKit ayrıca menü öğesi konumlarını yönetebilir. Kullanım yüzdeleri veya token uygulama tarafından diske yazılmaz. Uygulama mevcut oturum dosyalarını değiştirmez ve token yenilemez.

## Sınırlar ve güven varsayımları

- Kullanıcı hesabındaki Codex çalıştırılabilir dosyası ve kimlik bilgisi kaynağı güvenilir kabul edilir. Uygulama yüklenen CLI’ın imzasını doğrulamaz.
- Claude kullanım adresi genel ve resmî olarak belgelenmiş bir API değildir; yanıt biçimi değişebilir.
- Claude yanıtı `URLSession.data(for:)` ile belleğe tamamen alınır; Codex’teki 1 MiB sınırı Claude yanıtına uygulanmaz. Sabit hizmet adresi ve TLS dışında ayrı yanıt boyutu sınırı yoktur.
- HTTP 429 bekleme süresi uygulama yeniden başlatıldığında sıfırlanır.
- macOS menü öğelerini boş alan veya kullanıcı ayarları nedeniyle gizleyebilir; yalnızca bir sürecin çalışması görünürlüğü kanıtlamaz.
- Apple Silicon’da canlı kullanım doğrulandı. Intel dilimi derlenir ve paket yapısı kontrol edilir; Intel donanımında canlı test yapılmadı.
