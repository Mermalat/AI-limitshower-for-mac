# Sürüm notları

## Unreleased

- Added per-provider token totals and estimated USD API equivalents for today and the previous six local calendar days.
- Added daily bar charts and tables showing each date, exact token count, and estimated USD value. Days without usage remain visible with zero values.
- Added a persistent **Show / Hide token section** menu option. It controls totals, charts, and daily tables together; new local history scans stop while the section is hidden.
- Provider cards now open and close independently with header arrows. Collapsed cards keep the remaining quota visible.
- Fixed overlapping text and charts during resizing by updating content and window dimensions immediately. Only the chevron rotation remains animated, with support for Reduce Motion.
- Deduplicated repeated, forked, and streamed token records; accounted for cache read/write rates; added notices for incomplete history and unknown model prices.
- Added regression coverage for local day boundaries, daily totals, rapid card toggling, saved token visibility, and layout in all seven languages.

## GNOME 1.0.0-alpha.1 — 2026-10-13

- Added an independent GNOME Shell top bar port in `gnome/`, including provider indicators, dark expandable cards, weekly token/cost charts, seven languages and persistent preferences. Includes a user installer, extension ZIP builder, documentation and automated backend/lifecycle tests. This is a development build; real GNOME session testing remains pending.

## 1.2.0 — 2026-10-12

- Codex ve Claude ayrı ayrı açılıp kapatılabilir; son açık sağlayıcı kapatılamaz.
- Kapalı sağlayıcının menü çubuğu göstergesi ve kartı gizlenir, yeni sorguları durur; seçimler yeniden açılışta korunur.
- Panel tek sağlayıcıda küçülür, ikinci sağlayıcı açıldığında büyür. Eski yüksekliğin korunması hatası doğrudan AppKit boyutlandırmasıyla düzeltildi; uzun içerik ekran sınırında kaydırılır.
- Türkçe, İngilizce, İspanyolca, Japonca, basitleştirilmiş Çince, Almanca ve Fransızca dil seçimi eklendi. Metinler, hata mesajları ve tarihler seçilen dile uyarlanır; dil tercihi kaydedilir.
- Gerçek pencere küçülme/büyüme, ekran yüksekliği sınırı, sağlayıcı koruması ve yedi dil için testler eklendi.

## 1.1.0 — 2026-10-10

- Codex ve Claude Code simgeleri sağlanan SVG logolarıyla değiştirildi.
- Uygulama menüsünden Claude bağlantısını kapatma seçeneği kaldırıldı.
- Otomatik güncelleme aralığı panelden 1–10 dakika arasında seçilebilir ve yeniden açılışta korunur.

## 1.0.0 — 2026-10-10

İlk yayın.

- Codex ve Claude için ayrı menü çubuğu simgeleri ve kalan kota yüzdeleri.
- Kısa dönem, haftalık ve mevcutsa Claude model kotaları; yerel yenilenme saatleri.
- Beş dakikalık otomatik yenileme, sınırlı manuel yenileme ve eski veri göstergesi.
- Kullanıcının etkinleştirdiği Claude bağlantısı; token yalnızca Anthropic kullanım hizmetine gönderilir.
- Ekran içine yerleşen kaydırılabilir panel ve tek uygulama kopyası kontrolü.
- Apple Silicon ve Intel dilimlerini içeren macOS 13+ universal DMG.
- Türkçe kurulum ve geliştirme belgeleri, GPL-3.0-only kaynak lisansı, tam kaynak arşivi ve SHA-256 toplamları.

Developer ID imzası ve Apple noter onayı yoktur. Claude canlı sorgusu ve Intel donanımında çalıştırma bu sürümde doğrulanmadı. Resmî Codex/Claude marka simgeleri projenin GPL lisansına dahil değildir.
