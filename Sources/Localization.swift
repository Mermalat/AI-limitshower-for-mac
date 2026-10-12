// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Mermalat

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case tr, en, es, ja, zh, de, fr
    var id: String { rawValue }
    var name: String {
        switch self {
        case .tr: return "Türkçe"
        case .en: return "English"
        case .es: return "Español"
        case .ja: return "日本語"
        case .zh: return "简体中文"
        case .de: return "Deutsch"
        case .fr: return "Français"
        }
    }
    var locale: Locale { Locale(identifier: self == .zh ? "zh_Hans" : rawValue) }
}

enum L10n {
    // Columns follow AppLanguage.allCases, excluding the Turkish source column.
    static let translations: [String: [String]] = [
        "%@ ayrıntılarını aç": ["Expand %@ details", "Mostrar detalles de %@", "%@ の詳細を開く", "展开 %@ 详情", "%@-Details öffnen", "Afficher les détails de %@"],
        "%@ ayrıntılarını kapat": ["Collapse %@ details", "Ocultar detalles de %@", "%@ の詳細を閉じる", "收起 %@ 详情", "%@-Details schließen", "Masquer les détails de %@"],
        "Token bölümünü kapat": ["Hide token section", "Ocultar sección de tokens", "トークン欄を非表示", "隐藏 token 部分", "Tokenbereich ausblenden", "Masquer la section tokens"],
        "Token bölümünü aç": ["Show token section", "Mostrar sección de tokens", "トークン欄を表示", "显示 token 部分", "Tokenbereich einblenden", "Afficher la section tokens"],
        "Son 7 gün · token kullanımı": ["Last 7 days · token usage", "Últimos 7 días · tokens", "過去 7 日間 · トークン使用量", "最近 7 天 · token 用量", "Letzte 7 Tage · Tokenverbrauch", "7 derniers jours · tokens"],
        "Tahmini API karşılığı · fatura değildir": ["Estimated API equivalent · not a bill", "Estimación API · no es una factura", "API 相当の推定額 · 請求額ではありません", "估算 API 费用 · 非账单", "Geschätzter API-Wert · keine Rechnung", "Estimation API · pas une facture"],
        "Bazı modellerin fiyatı bilinmiyor; tutar eksik olabilir.": ["Some model prices are unknown; cost may be incomplete.", "Precios de algunos modelos desconocidos; el coste puede ser incompleto.", "一部のモデルの価格が不明なため、金額が不足する場合があります。", "部分模型价格未知，金额可能不完整。", "Einige Modellpreise fehlen; der Betrag kann unvollständig sein.", "Certains tarifs sont inconnus ; le montant peut être incomplet."],
        "Bazı yerel kayıtlar okunamadı; toplam eksik olabilir.": ["Some local records could not be read; totals may be incomplete.", "No se pudieron leer algunos registros; los totales pueden ser incompletos.", "一部のローカル記録を読み取れず、合計が不足する場合があります。", "部分本地记录无法读取，合计可能不完整。", "Einige lokale Einträge sind nicht lesbar; Summen können unvollständig sein.", "Certains journaux locaux sont illisibles ; les totaux peuvent être incomplets."],
        "Token kullanımı hesaplanıyor…": ["Calculating token usage…", "Calculando tokens…", "トークン使用量を計算中…", "正在计算 token 用量…", "Tokenverbrauch wird berechnet…", "Calcul des tokens…"],
        "Yerel kullanım kaydı bulunamadı.": ["No local usage records found.", "No hay registros de uso locales.", "ローカルの使用記録がありません。", "未找到本地用量记录。", "Keine lokalen Nutzungsdaten gefunden.", "Aucun journal d’utilisation local trouvé."],
        "Bugün dahil son 7 gün, bu Mac’in yerel saatine göre. Standart API karşılığı; fatura değildir.": ["Last 7 days including today, in this Mac’s local time. API equivalent, not a bill.", "Últimos 7 días, incluido hoy, en la hora local de este Mac. Estimación API, no factura.", "今日を含む過去 7 日間。この Mac の現地時間。API 相当額で、請求額ではありません。", "含今天在内的最近 7 天，按此 Mac 的本地时间。API 估算费用，非账单。", "Letzte 7 Tage einschließlich heute, lokale Zeit dieses Macs. API-Schätzung, keine Rechnung.", "7 derniers jours, aujourd’hui inclus, heure locale de ce Mac. Estimation API, pas une facture."],
        "Tarih": ["Date", "Fecha", "日付", "日期", "Datum", "Date"],

        "Kullanım durumu": ["Usage", "Uso", "使用状況", "使用情况", "Nutzung", "Utilisation"],
        "%@ · kalan kota": ["%@ · remaining quota", "%@ · cuota restante", "%@ · 残りの上限", "%@ · 剩余额度", "%@ · verbleibendes Kontingent", "%@ · quota restant"],
        "Codex ve Claude": ["Codex and Claude", "Codex y Claude", "Codex と Claude", "Codex 和 Claude", "Codex und Claude", "Codex et Claude"],
        "Bağlı değil": ["Not connected", "Sin conexión", "未接続", "未连接", "Nicht verbunden", "Non connecté"],
        "Bağlı": ["Connected", "Conectado", "接続済み", "已连接", "Verbunden", "Connecté"],
        "Mevcut Claude Code oturumunla limitlerini göster. Bağlantı, oturum token’ını yalnızca Anthropic’in kullanım servisine gönderir.": ["Show limits using your Claude Code session. Your session token is sent only to Anthropic’s usage service.", "Muestra los límites con tu sesión de Claude Code. El token de sesión se envía únicamente al servicio de uso de Anthropic.", "Claude Code のセッションで使用上限を表示します。セッショントークンは Anthropic の使用状況サービスにのみ送信されます。", "使用现有 Claude Code 会话显示额度。会话令牌仅发送到 Anthropic 的用量服务。", "Zeigt Limits mit deiner Claude-Code-Sitzung. Das Sitzungstoken wird nur an Anthropics Nutzungsdienst gesendet.", "Affiche les limites avec votre session Claude Code. Le jeton de session est envoyé uniquement au service d’utilisation d’Anthropic."],
        "Claude bağlantısını etkinleştir": ["Connect Claude", "Conectar Claude", "Claude に接続", "连接 Claude", "Claude verbinden", "Connecter Claude"],
        "Otomatik güncelleme": ["Auto refresh", "Actualización automática", "自動更新", "自动刷新", "Automatische Aktualisierung", "Actualisation automatique"],
        "%d dakika": ["%d min", "%d min", "%d 分", "%d 分钟", "%d Min.", "%d min"],
        "%d dakikada bir güncellenir": ["Refresh every %d min", "Actualizar cada %d min", "%d 分ごとに更新", "每 %d 分钟刷新", "Alle %d Min. aktualisieren", "Actualiser toutes les %d min"],
        "Otomatik güncelleme aralığını seç (1–10 dakika)": ["Choose refresh interval (1–10 minutes)", "Elige el intervalo (1–10 minutos)", "更新間隔を選択（1〜10 分）", "选择刷新间隔（1–10 分钟）", "Intervall wählen (1–10 Minuten)", "Choisir l’intervalle (1–10 minutes)"],
        "Şimdi yenile (en sık 30 saniyede bir)": ["Refresh now (at most every 30 seconds)", "Actualizar ahora (cada 30 segundos como mínimo)", "今すぐ更新（最短 30 秒間隔）", "立即刷新（至少间隔 30 秒）", "Jetzt aktualisieren (mindestens 30 Sekunden Abstand)", "Actualiser maintenant (30 secondes minimum)"],
        "Limitleri şimdi yenile": ["Refresh limits now", "Actualizar límites ahora", "使用上限を今すぐ更新", "立即刷新额度", "Limits jetzt aktualisieren", "Actualiser les limites"],
        "Codex’i kapat": ["Hide Codex", "Ocultar Codex", "Codex を非表示", "隐藏 Codex", "Codex ausblenden", "Masquer Codex"],
        "Codex’i aç": ["Show Codex", "Mostrar Codex", "Codex を表示", "显示 Codex", "Codex einblenden", "Afficher Codex"],
        "Claude’u kapat": ["Hide Claude", "Ocultar Claude", "Claude を非表示", "隐藏 Claude", "Claude ausblenden", "Masquer Claude"],
        "Claude’u aç": ["Show Claude", "Mostrar Claude", "Claude を表示", "显示 Claude", "Claude einblenden", "Afficher Claude"],
        "En az bir sağlayıcı açık kalmalı": ["Keep at least one provider enabled", "Debe quedar al menos un proveedor activo", "少なくとも 1 つを有効にしてください", "至少保留一个服务", "Mindestens ein Anbieter muss aktiv bleiben", "Au moins un fournisseur doit rester actif"],
        "Dil": ["Language", "Idioma", "言語", "语言", "Sprache", "Langue"],
        "Çıkış": ["Quit", "Salir", "終了", "退出", "Beenden", "Quitter"],
        "Uygulama menüsü": ["App menu", "Menú de la aplicación", "アプリメニュー", "应用菜单", "App-Menü", "Menu de l’application"],
        "Bağlantı yok": ["Connection unavailable", "Conexión no disponible", "接続できません", "无法连接", "Keine Verbindung", "Connexion indisponible"],
        "Eski veri": ["Stale data", "Datos antiguos", "古いデータ", "旧数据", "Veraltete Daten", "Données anciennes"],
        "Limitler okunuyor…": ["Loading limits…", "Cargando límites…", "使用上限を読み込み中…", "正在读取额度…", "Limits werden geladen…", "Chargement des limites…"],
        "Güncellendi: %@": ["Updated: %@", "Actualizado: %@", "更新: %@", "更新时间：%@", "Aktualisiert: %@", "Mis à jour : %@"],
        "%@ kullanım sayfasını aç": ["Open %@ usage page", "Abrir la página de uso de %@", "%@ の使用状況ページを開く", "打开 %@ 用量页面", "%@-Nutzungsseite öffnen", "Ouvrir la page d’utilisation de %@"],
        "kaldı": ["left", "restante", "残り", "剩余", "übrig", "restant"],
        "Yenilenme: %@": ["Resets: %@", "Se restablece: %@", "リセット: %@", "重置时间：%@", "Zurücksetzung: %@", "Réinitialisation : %@"],
        "Yenilenme zamanı geldi · güncelleme bekleniyor": ["Reset time reached · awaiting refresh", "Hora de reinicio alcanzada · esperando actualización", "リセット時刻になりました · 更新待ち", "已到重置时间 · 等待刷新", "Zurücksetzungszeit erreicht · warte auf Aktualisierung", "Heure de réinitialisation atteinte · actualisation en attente"],
        "Kullanılan: %d%%": ["Used: %d%%", "Usado: %d%%", "使用済み: %d%%", "已用：%d%%", "Verbraucht: %d%%", "Utilisé : %d%%"],
        "%@ %@ kaldı": ["%@ %@ remaining", "%@ %@ restante", "%@ 残り %@", "%@ 剩余 %@", "%@ %@ übrig", "%@ %@ restant"],
        "%@ · kısa dönem ve haftalık limitlerden en düşük kalan yüzde. ! = eski veri.": ["%@ · lowest remaining short-term or weekly quota. ! = stale data.", "%@ · menor cuota restante a corto plazo o semanal. ! = datos antiguos.", "%@ · 短期・週間上限の最小残量。! = 古いデータ。", "%@ · 短期或每周额度中最低的剩余百分比。! = 旧数据。", "%@ · niedrigster verbleibender Anteil der Kurzzeit- oder Wochenlimits. ! = veraltete Daten.", "%@ · plus faible quota restant à court terme ou hebdomadaire. ! = données anciennes."],
        "Haftalık": ["Weekly", "Semanal", "週間", "每周", "Wöchentlich", "Hebdomadaire"],
        "Kısa dönem": ["Short term", "Corto plazo", "短期", "短期", "Kurzfristig", "Court terme"],
        "Uzun dönem": ["Long term", "Largo plazo", "長期", "长期", "Langfristig", "Long terme"],
        "%d saatlik": ["%d-hour", "%d horas", "%d 時間", "%d 小时", "%d Stunden", "%d heures"],
        "%d dakikalık": ["%d-minute", "%d minutos", "%d 分", "%d 分钟", "%d Minuten", "%d minutes"],
        "%@ · haftalık": ["%@ · weekly", "%@ · semanal", "%@ · 週間", "%@ · 每周", "%@ · wöchentlich", "%@ · hebdomadaire"],
        "Sunucu çok sık sorgulandı. Bir süre sonra otomatik tekrar denenecek.": ["Too many requests. Will retry automatically later.", "Demasiadas solicitudes. Se reintentará automáticamente más tarde.", "リクエストが多すぎます。後で自動的に再試行します。", "请求过于频繁，稍后将自动重试。", "Zu viele Anfragen. Ein neuer Versuch erfolgt später automatisch.", "Trop de requêtes. Une nouvelle tentative aura lieu automatiquement."],
        "Sunucudan geçersiz yanıt geldi.": ["Invalid server response.", "Respuesta del servidor no válida.", "サーバーから無効な応答がありました。", "服务器响应无效。", "Ungültige Serverantwort.", "Réponse du serveur invalide."],
        "Codex limit verisi yok. ChatGPT hesabıyla Codex’e giriş yap.": ["No Codex limit data. Sign in to Codex with your ChatGPT account.", "No hay datos de límites de Codex. Inicia sesión con tu cuenta de ChatGPT.", "Codex の上限データがありません。ChatGPT アカウントで Codex にログインしてください。", "没有 Codex 额度数据。请使用 ChatGPT 账户登录 Codex。", "Keine Codex-Limitdaten. Mit dem ChatGPT-Konto bei Codex anmelden.", "Aucune donnée de limite Codex. Connectez-vous avec votre compte ChatGPT."],
        "Codex bu hesap için limit yüzdesi döndürmedi.": ["Codex returned no quota percentage for this account.", "Codex no devolvió un porcentaje para esta cuenta.", "このアカウントの Codex 使用上限が取得できません。", "Codex 未返回此账户的额度百分比。", "Codex lieferte keinen Limitanteil für dieses Konto.", "Codex n’a pas renvoyé de pourcentage pour ce compte."],
        "Claude bu hesap için limit yüzdesi döndürmedi.": ["Claude returned no quota percentage for this account.", "Claude no devolvió un porcentaje para esta cuenta.", "このアカウントの Claude 使用上限が取得できません。", "Claude 未返回此账户的额度百分比。", "Claude lieferte keinen Limitanteil für dieses Konto.", "Claude n’a pas renvoyé de pourcentage pour ce compte."],
        "Claude Code oturumu yok. Terminal’de claude açıp /login çalıştır.": ["No Claude Code session. Open claude in Terminal and run /login.", "No hay sesión de Claude Code. Abre claude en Terminal y ejecuta /login.", "Claude Code のセッションがありません。ターミナルで claude を開き /login を実行してください。", "没有 Claude Code 会话。请在终端打开 claude 并运行 /login。", "Keine Claude-Code-Sitzung. Im Terminal claude öffnen und /login ausführen.", "Aucune session Claude Code. Ouvrez claude dans le Terminal et lancez /login."],
        "Claude oturumu süresi doldu. Claude Code’u açarak oturumu yenile, sonra tekrar dene.": ["Claude session expired. Renew it in Claude Code, then retry.", "La sesión de Claude ha caducado. Renuévala en Claude Code e inténtalo de nuevo.", "Claude のセッションが期限切れです。Claude Code で更新して再試行してください。", "Claude 会话已过期。请在 Claude Code 中更新会话后重试。", "Claude-Sitzung abgelaufen. In Claude Code erneuern und erneut versuchen.", "La session Claude a expiré. Renouvelez-la dans Claude Code, puis réessayez."],
        "Claude oturumunda kullanım okuma izni yok. Claude Code’da /login ile tekrar giriş yap.": ["Claude session cannot read usage. Sign in again with /login in Claude Code.", "La sesión no tiene permiso de lectura de uso. Vuelve a iniciar sesión con /login en Claude Code.", "使用状況の読み取り権限がありません。Claude Code で /login を実行してください。", "Claude 会话无权读取用量。请在 Claude Code 中使用 /login 重新登录。", "Keine Berechtigung zum Lesen der Nutzung. In Claude Code mit /login neu anmelden.", "La session ne peut pas lire l’utilisation. Reconnectez-vous avec /login dans Claude Code."],
        "Bağlantı zaman aşımına uğradı. Tekrar dene.": ["Connection timed out. Try again.", "La conexión agotó el tiempo de espera. Inténtalo de nuevo.", "接続がタイムアウトしました。再試行してください。", "连接超时，请重试。", "Zeitüberschreitung. Erneut versuchen.", "La connexion a expiré. Réessayez."],
        "Yerel uygulamayla bağlantı kurulamadı.": ["Could not connect to the local app.", "No se pudo conectar con la aplicación local.", "ローカルアプリに接続できませんでした。", "无法连接本地应用。", "Keine Verbindung zur lokalen App.", "Connexion à l’application locale impossible."],
        "Codex limitleri okunamadı. Terminal’de codex login ile oturumunu kontrol et.": ["Could not read Codex limits. Check your session with codex login in Terminal.", "No se pudieron leer los límites. Comprueba tu sesión con codex login en Terminal.", "Codex の上限を読み取れません。ターミナルで codex login を確認してください。", "无法读取 Codex 额度。请在终端使用 codex login 检查会话。", "Codex-Limits konnten nicht gelesen werden. Sitzung mit codex login im Terminal prüfen.", "Impossible de lire les limites Codex. Vérifiez la session avec codex login dans le Terminal."],
        "Codex bağlantısı kapandı. Codex kurulumunu ve oturumunu kontrol et.": ["Codex connection closed. Check its installation and session.", "La conexión de Codex se cerró. Comprueba la instalación y la sesión.", "Codex の接続が閉じました。インストールとセッションを確認してください。", "Codex 连接已关闭。请检查安装和会话。", "Codex-Verbindung geschlossen. Installation und Sitzung prüfen.", "Connexion Codex fermée. Vérifiez l’installation et la session."],
        "Yerel uygulamadan beklenmeyen yanıt geldi.": ["Unexpected response from the local app.", "Respuesta inesperada de la aplicación local.", "ローカルアプリから予期しない応答がありました。", "本地应用返回了意外响应。", "Unerwartete Antwort der lokalen App.", "Réponse inattendue de l’application locale."],
        "Codex bulunamadı. Önce Codex CLI kurup ChatGPT hesabınla giriş yap.": ["Codex not found. Install Codex CLI and sign in with ChatGPT.", "No se encontró Codex. Instala Codex CLI e inicia sesión con ChatGPT.", "Codex が見つかりません。Codex CLI をインストールして ChatGPT でログインしてください。", "未找到 Codex。请安装 Codex CLI 并使用 ChatGPT 登录。", "Codex nicht gefunden. Codex CLI installieren und mit ChatGPT anmelden.", "Codex introuvable. Installez Codex CLI et connectez-vous avec ChatGPT."],
        "Claude Code oturumu okunamadı. Anahtar Zinciri erişimini ve Claude Code’da /login oturumunu kontrol et.": ["Could not read the Claude Code session. Check Keychain access and /login in Claude Code.", "No se pudo leer la sesión. Comprueba el acceso al llavero y /login en Claude Code.", "Claude Code のセッションを読み取れません。キーチェーンのアクセスと /login を確認してください。", "无法读取 Claude Code 会话。请检查钥匙串访问权限和 Claude Code 的 /login 会话。", "Claude-Code-Sitzung nicht lesbar. Schlüsselbundzugriff und /login prüfen.", "Impossible de lire la session Claude Code. Vérifiez le trousseau et /login dans Claude Code."],
        "Claude’a ulaşılamadı. İnternet bağlantını kontrol et.": ["Could not reach Claude. Check your internet connection.", "No se pudo contactar con Claude. Comprueba tu conexión a internet.", "Claude に接続できません。インターネット接続を確認してください。", "无法访问 Claude。请检查网络连接。", "Claude nicht erreichbar. Internetverbindung prüfen.", "Claude inaccessible. Vérifiez la connexion Internet."],
        "Claude’dan geçersiz yanıt geldi.": ["Invalid response from Claude.", "Respuesta de Claude no válida.", "Claude から無効な応答がありました。", "Claude 响应无效。", "Ungültige Antwort von Claude.", "Réponse de Claude invalide."],
        "Claude oturumu kabul edilmedi. Claude Code’da /login ile oturumunu yenile.": ["Claude session rejected. Renew it with /login in Claude Code.", "La sesión de Claude fue rechazada. Renuévala con /login en Claude Code.", "Claude のセッションが拒否されました。Claude Code で /login を実行してください。", "Claude 会话被拒绝。请在 Claude Code 中使用 /login 更新会话。", "Claude-Sitzung abgelehnt. Mit /login in Claude Code erneuern.", "Session Claude refusée. Renouvelez-la avec /login dans Claude Code."],
        "%@ başlatılamadı.": ["Could not start %@.", "No se pudo iniciar %@.", "%@ を起動できませんでした。", "无法启动 %@。", "%@ konnte nicht gestartet werden.", "Impossible de démarrer %@."],
        "Claude geçici olarak kullanılamıyor (HTTP %@).": ["Claude is temporarily unavailable (HTTP %@).", "Claude no está disponible temporalmente (HTTP %@).", "Claude は一時的に利用できません（HTTP %@）。", "Claude 暂时不可用（HTTP %@）。", "Claude vorübergehend nicht verfügbar (HTTP %@).", "Claude est temporairement indisponible (HTTP %@)."],
        "Veri okunamadı. Tekrar dene.": ["Could not read data. Try again.", "No se pudieron leer los datos. Inténtalo de nuevo.", "データを読み取れませんでした。再試行してください。", "无法读取数据，请重试。", "Daten konnten nicht gelesen werden. Erneut versuchen.", "Impossible de lire les données. Réessayez."]
    ]

    static func text(_ key: String, _ language: AppLanguage, _ arguments: CVarArg...) -> String {
        let index = AppLanguage.allCases.firstIndex(of: language)! - 1
        let format = language == .tr ? key : translations[key]?[index] ?? key
        return String(format: format, locale: language.locale, arguments: arguments)
    }

    static func windowTitle(_ title: String, _ language: AppLanguage) -> String {
        if title.hasSuffix(" saatlik"), let count = Int(title.split(separator: " ")[0]) {
            return text("%d saatlik", language, count)
        }
        if title.hasSuffix(" dakikalık"), let count = Int(title.split(separator: " ")[0]) {
            return text("%d dakikalık", language, count)
        }
        if title.hasSuffix(" · haftalık") {
            return text("%@ · haftalık", language, String(title.dropLast(" · haftalık".count)))
        }
        return text(title, language)
    }

    static func error(_ error: Error, _ language: AppLanguage) -> String {
        guard let error = error as? UsageError else { return text("Veri okunamadı. Tekrar dene.", language) }
        switch error {
        case .message(let key): return text(key, language)
        case .formatted(let key, let value): return text(key, language, value)
        case .rateLimited: return text("Sunucu çok sık sorgulandı. Bir süre sonra otomatik tekrar denenecek.", language)
        }
    }
}
