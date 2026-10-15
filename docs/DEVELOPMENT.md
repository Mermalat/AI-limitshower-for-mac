# Geliştirme ve paketleme

## Derleme

macOS, Xcode veya Apple Command Line Tools, Swift derleyicisi ve macOS SDK gerekir. Üçüncü taraf Swift paketi yoktur. Gereken araçlar: `xcrun`, `swiftc`, `lipo`, `codesign`, `hdiutil`, `ditto`, `tar`, `shasum`.

```sh
./build.sh
./run.sh
```

Yerel mimariye derlenen çıktı `build/AIlimitshower.app` olur. Çalışmakta olan aynı paket üzerine yeniden derlemeden önce uygulamayı kapat. İki mimarili sürüm için:

```sh
./build.sh --universal
```

Bu çıktı `build/universal/AIlimitshower.app` içinde oluşur; yerel geliştirme paketi değiştirilmez. `arm64` ve `x86_64` ayrı derlenip `lipo` ile birleştirilir. Minimum macOS hedefi 13.0’dır. Sürümün tek kaynağı `VERSION` dosyasıdır. Paket kimliği `com.mermalat.TopBarClaudeCodexLimits` olarak sabittir; yeni sürümlerde değiştirilmemelidir.

## Test

```sh
./test.sh
```

Kontroller XCTest yerine küçük bir komut satırı test programındaki assert’lerle yapılır. Testler yüzde hesabı, JSON biçimleri, zaman damgaları, eksik ve bozuk veri, kimlik bilgisi seçimi, token süresi, satırlı süreç yanıtları, zaman aşımı panel konumlarını, tek sağlayıcı korumasını, kalıcı tercihleri ve yedi dilin çeviri biçimlerini kapsar. Gerçek token fixture olarak kullanılmaz.

```sh
./test.sh --live-codex
```

Bu ek kontrol mevcut Codex oturumuyla gerçek limitleri okur. Claude için otomatik canlı test yoktur; kullanıcı bağlantıyı arayüzden etkinleştirir.

Menü öğeleri ve panel için ayrıca gerçek macOS arayüzünde kontrol yap: iki simge görünmeli, iki simge de paneli açmalı, dışarı tıklamak paneli kapatmalı ve panel kapandıktan sonra göstergeler kalmalıdır. Uzun içerik ve çoklu ekran düzeni de kontrol edilmelidir. Ekran konumu hesabının birim testleri gerçek menü çubuğu görünürlüğünün yerine geçmez.

## DMG ve kaynak arşivi

```sh
./package.sh
```

Betik testleri çalıştırır, universal paketi derler, iki mimariyi ve ad-hoc imzayı doğrular. DMG’ye `.app`, `/Applications` kısayolu, kurulum rehberi, GPL metni ve üçüncü taraf bildirimleri eklenir. Sonra `hdiutil verify` ile DMG bütünlüğü kontrol edilir.

`dist/` altında şu dosyalar oluşur:

- `TopBarClaudeCodexLimits-<sürüm>-universal.dmg`
- `TopBarClaudeCodexLimits-<sürüm>-source.tar.gz`
- `SHA256SUMS.txt`

Kaynak arşivi açık bir dosya listesi kullanır; ev klasörünü, `.git`, `build`, `dist` veya oturum bilgilerini toplamaz. Arşiv, kaynaklarla birlikte testleri ve derleme betiklerini içerir. Release yayımlarken DMG ile aynı sürümün kaynak arşivini ve sağlama toplamlarını da yükle.

Bu betik Developer ID sertifikası kullanmaz ve Apple noter onayı başlatmaz. Noter onaylı bir yayın için ayrıca uygun Apple Developer hesabı, Developer ID imzası ve Apple’ın notarization akışı gerekir. Bu kimlik bilgileri projede saklanmamalıdır.

## Sürüm hazırlığı

`VERSION` ve `CHANGELOG.md` dosyalarını güncelle. Güvenlik kontrolünü ve testleri tamamla, `./package.sh` çalıştır, DMG’yi salt okunur bağlayarak içeriğini ve imzayı kontrol et. İlgili kaynak commit’ine `v<sürüm>` etiketi ekle ve GitHub Release’e üç dağıtım dosyasını yükle. `build/` ve `dist/` Git’e dahil edilmez.

Kod GPL-3.0-only kapsamındadır. Yeni özgün kaynaklara aynı SPDX başlığını ekle. Üçüncü taraf simgeler için ayrıca `THIRD_PARTY_NOTICES.md` dosyasını koru.

## Uygulama simgesi

Roket simgesi `Assets/AppIcon.icns` içindedir. macOS’un emoji fontu ve AppKit ile tekrar oluşturmak için:

```sh
xcrun swift Scripts/generate-app-icon.swift
iconutil -c icns build/AIlimitshower.iconset -o Assets/AppIcon.icns
```

Finder ve Raycast için görünen ad `AIlimitshower` olur; paket kimliği ve tercihler korunur.

## Bellek kontrolü

`./test.sh`, token geçmişi okuyucusunun geçici nesneleri tarama boyunca biriktirmediğini denetleyen bellek testini de çalıştırır. Daha büyük iş yükü için `build/memory-tests --stress` kullanılabilir. Ölçümler ve yöntemin sınırları [bellek raporunda](PERFORMANCE.md) bulunur.
