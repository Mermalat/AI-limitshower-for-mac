// SPDX-License-Identifier: GPL-3.0-only
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {PROVIDERS, translate, locale, graphHeights, quotaColor} from './logic.js';

function box(vertical = false, options = {}) {
    const direction = 'orientation' in St.BoxLayout.prototype
        ? {orientation: vertical ? Clutter.Orientation.VERTICAL : Clutter.Orientation.HORIZONTAL}
        : {vertical};
    return new St.BoxLayout({...direction, ...options});
}
function label(text, style = '') {
    const actor = new St.Label({text: String(text), style_class: style});
    actor.get_clutter_text().set_line_wrap(true);
    return actor;
}
function readJSON(path) {
    const [, bytes] = Gio.File.new_for_path(path).load_contents(null);
    return JSON.parse(new TextDecoder().decode(bytes));
}

export default class LimitsExtension extends Extension {
    enable() {
        this._active = true;
        this._settings = this.getSettings();
        this._catalog = readJSON(`${this.path}/translations.json`);
        this._data = {codex: {}, claude: {}};
        this._expanded = {codex: false, claude: false};
        this._jobs = new Map();
        this._buttons = new Map();
        this._lastRefresh = 0;
        this._queried = {};
        this._signal = this._settings.connect('changed', (_settings, key) => {
            if (key === 'claude-connected') {
                this._cancel('claude');
                this._queried.claude = 0;
            }
            if (key === 'codex-path') {
                this._cancel('codex');
                this._queried.codex = 0;
            }
            this._enforceVisibility();
            // Revoke consent immediately, including an in-flight request.
            for (const p of PROVIDERS) {
                if (!this._settings.get_boolean(`${p}-visible`) ||
                    (p === 'claude' && !this._settings.get_boolean('claude-connected'))) {
                    this._cancel(p);
                    if (p === 'claude') this._data[p] = {...this._data[p], snapshot: null, error: null};
                }
            }
            this._syncButtons();
            this._restartTimer();
            this._render();
            if (['claude-connected', 'codex-path', 'codex-visible', 'claude-visible', 'tokens-visible'].includes(key))
                this._refresh(false);
        });
        this._enforceVisibility();
        this._syncButtons();
        this._restartTimer();
        this._render();
        this._refresh(false);
    }
    _t(key, ...args) { return translate(key, this._settings.get_string('language'), this._catalog, ...args); }
    _locale() { return locale(this._settings.get_string('language')); }
    _visible() { return Object.fromEntries(PROVIDERS.map(p => [p, this._settings.get_boolean(`${p}-visible`)])); }
    _enforceVisibility() {
        const visible = this._visible();
        if (!visible.codex && !visible.claude) this._settings.set_boolean('codex-visible', true);
    }
    _icon(p, size = 24) {
        return new St.Icon({gicon: Gio.icon_new_for_string(`${this.path}/assets/${p}.png`), icon_size: size});
    }
    _syncButtons() {
        for (const p of PROVIDERS) {
            if (!this._settings.get_boolean(`${p}-visible`)) {
                this._buttons.get(p)?.button.destroy();
                this._buttons.delete(p);
            } else if (!this._buttons.has(p)) {
                const button = new PanelMenu.Button(0.5, `${p} limits`);
                const content = box(false, {style_class: 'ai-panel-label'});
                const text = label('—');
                content.add_child(this._icon(p, 16));
                content.add_child(text);
                button.add_child(content);
                Main.panel.addToStatusArea(`${this.uuid}-${p}`, button);
                this._buttons.set(p, {button, text});
            }
        }
    }
    _restartTimer() {
        if (this._timer) GLib.Source.remove(this._timer);
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT,
            this._settings.get_int('refresh-minutes') * 60, () => {
                this._refresh(false);
                return GLib.SOURCE_CONTINUE;
            });
    }
    _cancel(p) {
        const job = this._jobs.get(p);
        if (job) {
            this._jobs.delete(p);
            job.cancel.cancel();
            job.process.force_exit();
        }
    }
    _refresh(manual) {
        const now = Date.now() / 1000;
        if (manual && now - this._lastRefresh < 30) return;
        this._lastRefresh = now;
        for (const p of PROVIDERS) {
            if (!this._settings.get_boolean(`${p}-visible`) || this._jobs.has(p)) continue;
            const connected = p !== 'claude' || this._settings.get_boolean('claude-connected');
            const history = this._settings.get_boolean('tokens-visible');
            if (!connected && !history) continue;
            if (connected && now < (this._data[p].retryAt ?? 0)) continue;
            if (now - (this._queried[p] ?? 0) < 30) continue;
            this._queried[p] = now;
            const args = ['/usr/bin/python3', `${this.path}/backend.py`, '--provider', p];
            if (history) args.push('--history');
            if (!connected) args.push('--history-only');
            if (p === 'claude' && connected) args.push('--allow-claude');
            const codexPath = this._settings.get_string('codex-path');
            if (p === 'codex' && codexPath) args.push('--codex-path', codexPath);
            try {
                const process = Gio.Subprocess.new(args, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
                const job = {process, cancel: new Gio.Cancellable()};
                this._jobs.set(p, job);
                process.communicate_utf8_async(null, job.cancel, (proc, result) => {
                    if (!this._active || this._jobs.get(p) !== job) return;
                    this._jobs.delete(p);
                    try {
                        const [, output] = proc.communicate_utf8_finish(result);
                        if (!proc.get_successful() || output.length > 1048576) throw new Error('worker failed');
                        const data = JSON.parse(output);
                        // Keep the last successful quota on temporary network failure.
                        this._data[p] = {...this._data[p], ...data};
                        if (data.snapshot) this._data[p].error = null;
                    } catch (_) {
                        this._data[p].error = 'Veri okunamadı. Tekrar dene.';
                    }
                    this._render();
                });
            } catch (_) { this._data[p].error = 'Veri okunamadı. Tekrar dene.'; }
        }
    }
    _date(seconds) {
        return seconds ? new Date(seconds * 1000).toLocaleString(this._locale(), {day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'}) : '—';
    }
    _tokens(value) { return Math.round(value ?? 0).toLocaleString(this._locale()); }
    _cost(value) { return new Intl.NumberFormat(this._locale(), {style: 'currency', currency: 'USD', maximumFractionDigits: 3}).format(value ?? 0); }
    _row(left, right, style = '', color = null) {
        const row = box(false, {style_class: 'ai-row'});
        row.add_child(label(left, style));
        const value = label(right, style);
        if (color) value.set_style(`color: ${color};`);
        value.x_expand = true;
        value.x_align = Clutter.ActorAlign.END;
        row.add_child(value);
        return row;
    }
    _card(p) {
        const data = this._data[p];
        const card = box(true, {style_class: `ai-card ai-${p}`});
        const header = box(false, {style_class: 'ai-card-header'});
        header.add_child(this._icon(p));
        header.add_child(label(p === 'codex' ? 'Codex' : 'Claude', 'ai-provider'));
        const plan = label(data.snapshot?.plan ?? (p === 'claude' && !this._settings.get_boolean('claude-connected') ? this._t('Bağlı değil') : ''), 'ai-muted');
        plan.x_expand = true;
        plan.x_align = Clutter.ActorAlign.END;
        header.add_child(plan);
        const toggle = new St.Button({label: this._expanded[p] ? '⌃' : '⌄', style_class: 'ai-chevron', accessible_name: p});
        header.add_child(toggle);
        card.add_child(header);
        const detail = box(true, {style_class: 'ai-detail', visible: this._expanded[p]});
        toggle.connect('clicked', () => {
            this._expanded[p] = !this._expanded[p];
            // Resize naturally without scaling text or moving chart actors over each other.
            for (const item of this._buttons.values()) {
                item.details?.[p]?.set_visible(this._expanded[p]);
                item.toggles?.[p]?.set_label(this._expanded[p] ? '⌃' : '⌄');
            }
        });
        const summary = data.snapshot?.remaining;
        card.add_child(this._row(this._t('Kalan kota'), summary == null ? '—' : `${Math.round(summary)}%`, 'ai-summary', summary == null ? null : quotaColor(p, summary)));
        for (const window of data.snapshot?.windows ?? []) {
            let title = this._t(window.title);
            const hours = window.title.match(/^(\d+) saatlik$/);
            const minutes = window.title.match(/^(\d+) dakikalık$/);
            if (hours) title = this._t('%d saatlik', hours[1]);
            if (minutes) title = this._t('%d dakikalık', minutes[1]);
            detail.add_child(this._row(title, `${Math.round(window.remaining)}% ${this._t('kaldı')}`, 'ai-limit', quotaColor(p, window.remaining)));
            const track = box(false, {style_class: 'ai-track', x_expand: true});
            const fill = new St.Widget({style_class: 'ai-fill', height: 5});
            fill.set_style(`background-color: ${quotaColor(p, window.remaining)};`);
            track.add_child(fill);
            track.connect('notify::width', () => fill.set_width(Math.max(0, track.width * window.remaining / 100)));
            detail.add_child(track);
            detail.add_child(label(`${this._t('Yenilenme: %@', this._date(window.reset))}`, 'ai-muted'));
        }
        if (data.error) {
            if (data.snapshot) detail.add_child(label(this._t('Eski veri'), 'ai-message'));
            detail.add_child(label(this._t(data.error), 'ai-message'));
        }
        if (p === 'claude' && !this._settings.get_boolean('claude-connected')) {
            detail.add_child(label(this._t('Mevcut Claude Code oturumunla limitlerini göster. Bağlantı, oturum token’ını yalnızca Anthropic’in kullanım servisine gönderir.'), 'ai-message'));
            const connect = new St.Button({label: this._t('Claude bağlantısını etkinleştir'), style_class: 'ai-connect'});
            connect.connect('clicked', () => this._settings.set_boolean('claude-connected', true));
            detail.add_child(connect);
        }
        if (this._settings.get_boolean('tokens-visible')) this._history(detail, data.history);
        if (data.snapshot) detail.add_child(label(this._t('Güncellendi: %@', this._date(data.snapshot.updated)), 'ai-muted'));
        card.add_child(detail);
        return {card, detail, toggle};
    }
    _history(parent, history) {
        parent.add_child(label(this._t('Son 7 gün · token kullanımı'), 'ai-section'));
        if (!history?.available) {
            parent.add_child(label(this._t('Yerel kullanım kaydı bulunamadı.'), 'ai-muted'));
            return;
        }
        parent.add_child(this._row(`${this._tokens(history.tokens)} ${this._t('token')}`, this._cost(history.usd), 'ai-total'));
        const chart = box(false, {style_class: 'ai-chart'});
        const heights = graphHeights(history.days);
        history.days.forEach((day, i) => {
            const column = box(true, {x_expand: true, style_class: 'ai-column'});
            const space = new St.Widget({height: 80 - heights[i]});
            const bar = new St.Widget({height: heights[i], style_class: 'ai-bar'});
            column.add_child(space);
            column.add_child(bar);
            column.add_child(label(day.date.slice(8), 'ai-day'));
            chart.add_child(column);
        });
        parent.add_child(chart);
        for (const day of history.days) {
            const date = new Date(`${day.date}T12:00:00`).toLocaleDateString(this._locale(), {day: 'numeric', month: 'short'});
            parent.add_child(this._row(date, `${this._tokens(day.tokens)} · ${this._cost(day.usd)}${day.unpriced ? ' *' : ''}`, 'ai-daily'));
        }
        parent.add_child(label(this._t('API fiyat tahmini · fatura değil'), 'ai-muted'));
        if (history.unpriced) parent.add_child(label(this._t('Bazı modellerin fiyatı bilinmiyor; tutar eksik olabilir.'), 'ai-message'));
        if (history.incomplete) parent.add_child(label(this._t('Bazı yerel kayıtlar okunamadı; toplam eksik olabilir.'), 'ai-message'));
    }
    _render() {
        for (const [provider, item] of this._buttons) {
            const value = this._data[provider].snapshot?.remaining;
            item.text.set_text(value == null ? '—' : `${Math.round(value)}%${this._data[provider].error ? '!' : ''}`);
            item.text.set_style(value == null ? '' : `color: ${quotaColor(provider, value)};`);
            item.button.menu.removeAll();
            const shellItem = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
            const scroll = new St.ScrollView({style_class: 'ai-scroll', overlay_scrollbars: true});
            const monitor = Main.layoutManager.findMonitorForActor?.(item.button) ?? Main.layoutManager.primaryMonitor;
            scroll.set_style(`max-height: ${Math.max(200, (monitor?.height ?? 900) - 100)}px;`);
            const content = box(true, {style_class: 'ai-content'});
            content.add_child(label(this._t('Kullanım durumu'), 'ai-title'));
            content.add_child(label(this._t('%@ · kalan kota', 'Codex & Claude'), 'ai-muted'));
            item.details = {};
            item.toggles = {};
            for (const p of PROVIDERS.filter(p => this._settings.get_boolean(`${p}-visible`))) {
                const {card, detail, toggle} = this._card(p);
                item.details[p] = detail;
                item.toggles[p] = toggle;
                content.add_child(card);
            }
            content.add_child(label(this._t('%d dakikada bir güncellenir', this._settings.get_int('refresh-minutes')), 'ai-muted'));
            if (scroll.set_child) scroll.set_child(content); else scroll.add_actor(content);
            shellItem.add_child(scroll);
            item.button.menu.addMenuItem(shellItem);
            const refresh = new PopupMenu.PopupMenuItem(this._t('Şimdi güncelle'));
            refresh.connect('activate', () => this._refresh(true));
            item.button.menu.addMenuItem(refresh);
            const settings = new PopupMenu.PopupMenuItem(this._t('Ayarlar'));
            settings.connect('activate', () => this.openPreferences());
            item.button.menu.addMenuItem(settings);
        }
    }
    disable() {
        this._active = false;
        if (this._timer) GLib.Source.remove(this._timer);
        this._timer = 0;
        this._settings?.disconnect(this._signal);
        for (const p of PROVIDERS) this._cancel(p);
        for (const item of this._buttons.values()) item.button.destroy();
        this._buttons.clear();
        this._settings = null;
        this._data = null;
        this._catalog = null;
    }
}
