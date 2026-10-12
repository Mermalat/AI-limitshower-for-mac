// SPDX-License-Identifier: GPL-3.0-only
import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';
import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';
import {PROVIDERS, LANGUAGES, canHide, translate} from './logic.js';

export default class LimitsPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();
        const [, bytes] = Gio.File.new_for_path(`${this.path}/translations.json`).load_contents(null);
        const catalog = JSON.parse(new TextDecoder().decode(bytes));
        const t = (key, ...args) => translate(key, settings.get_string('language'), catalog, ...args);
        const page = new Adw.PreferencesPage({title: t('Ayarlar'), icon_name: 'preferences-system-symbolic'});
        const group = new Adw.PreferencesGroup({title: 'Claude & Codex Limits'});
        page.add(group);
        window.add(page);
        const switches = {};
        const refreshSensitivity = () => {
            const visible = Object.fromEntries(PROVIDERS.map(p => [p, settings.get_boolean(`${p}-visible`)]));
            for (const p of PROVIDERS) switches[p].sensitive = !visible[p] || canHide(p, visible);
        };
        for (const p of PROVIDERS) {
            const row = new Adw.SwitchRow({title: t('%@ göster', p === 'codex' ? 'Codex' : 'Claude')});
            settings.bind(`${p}-visible`, row, 'active', Gio.SettingsBindFlags.DEFAULT);
            switches[p] = row;
            row.connect('notify::active', () => {
                // Enforce this invariant even when the extension itself is disabled.
                if (!settings.get_boolean('codex-visible') && !settings.get_boolean('claude-visible'))
                    settings.set_boolean(`${p}-visible`, true);
                refreshSensitivity();
            });
            group.add(row);
        }
        refreshSensitivity();
        const tokens = new Adw.SwitchRow({title: t('Token bölümünü göster')});
        settings.bind('tokens-visible', tokens, 'active', Gio.SettingsBindFlags.DEFAULT);
        group.add(tokens);
        const consent = new Adw.SwitchRow({title: t('Claude bağlantısını etkinleştir'), subtitle: t('Mevcut Claude Code oturumunla limitlerini göster. Bağlantı, oturum token’ını yalnızca Anthropic’in kullanım servisine gönderir.')});
        settings.bind('claude-connected', consent, 'active', Gio.SettingsBindFlags.DEFAULT);
        group.add(consent);
        const minutes = new Adw.ActionRow({title: t('Otomatik güncelleme'), subtitle: t('Otomatik güncelleme aralığını seç (1–10 dakika)')});
        const spin = new Gtk.SpinButton({adjustment: new Gtk.Adjustment({lower: 1, upper: 10, step_increment: 1, page_increment: 1}), numeric: true, valign: Gtk.Align.CENTER});
        settings.bind('refresh-minutes', spin, 'value', Gio.SettingsBindFlags.DEFAULT);
        minutes.add_suffix(spin);
        minutes.activatable_widget = spin;
        group.add(minutes);
        const language = new Adw.ComboRow({title: t('Dil'), model: Gtk.StringList.new(['Türkçe', 'English', 'Español', '日本語', '简体中文', 'Deutsch', 'Français']), selected: Math.max(0, LANGUAGES.indexOf(settings.get_string('language')))});
        language.connect('notify::selected', () => settings.set_string('language', LANGUAGES[language.selected]));
        group.add(language);
        const path = new Adw.EntryRow({title: t('Codex CLI yolu (isteğe bağlı)'), text: settings.get_string('codex-path'), show_apply_button: true});
        path.connect('apply', () => settings.set_string('codex-path', path.text.trim()));
        group.add(path);
        group.add(new Adw.ActionRow({title: t('API fiyat tahmini · fatura değil'), subtitle: t('Fiyat tablosu: 12 Ekim 2026. Yerel kayıtlar kullanılır.')}));
    }
}
