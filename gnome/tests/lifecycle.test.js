// SPDX-License-Identifier: GPL-3.0-only
// Shell API doubles exercise our lifecycle; they do not replace a real GNOME smoke test.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

async function loadExtension() {
    const timers = new Set(), processes = [], panel = new Map();
    class Actor {
        constructor(props = {}) {Object.assign(this, props); this.children = []; this.handlers = new Map();}
        add_child(child) {this.children.push(child);}
        add_actor(child) {this.add_child(child);}
        set_child(child) {this.children = [child];}
        set_style(value) {this.style = value;}
        set_text(value) {this.text = value;}
        set_label(value) {this.label = value;}
        set_visible(value) {this.visible = value;}
        get_clutter_text() {return {set_line_wrap() {}};}
        connect(event, handler) {this.handlers.set(event, handler); return 1;}
        destroy() {this.destroyed = true;}
    }
    class Menu {constructor() {this.items = [];} removeAll() {this.items = [];} addMenuItem(item) {this.items.push(item);}}
    class PanelButton extends Actor {constructor() {super(); this.menu = new Menu();}}
    const values = {'codex-visible': true, 'claude-visible': true, 'claude-connected': false, 'tokens-visible': true, 'language': 'en', 'refresh-minutes': 5, 'codex-path': ''};
    const settings = {
        get_boolean: key => values[key], get_string: key => values[key], get_int: key => values[key],
        set_boolean(key, value) {if (values[key] === value) return; values[key] = value; this.handler?.(this, key);},
        connect(_signal, callback) {this.handler = callback; return 1;},
        disconnect() {this.handler = null;},
    };
    const Gio = {
        File: {new_for_path: path => ({load_contents: () => [true, fs.readFileSync(path)]})},
        icon_new_for_string: path => path,
        Cancellable: class {cancel() {this.cancelled = true;}},
        SubprocessFlags: {STDOUT_PIPE: 1, STDERR_SILENCE: 2},
        Subprocess: {new(args) {
            const process = {args, killed: false, force_exit() {this.killed = true;},
                communicate_utf8_async(_input, cancel, callback) {this.callback = callback; this.cancel = cancel;},
                communicate_utf8_finish() {return [true, JSON.stringify({snapshot: {remaining: 75, windows: [], updated: 1}, history: {available: false}})];},
                get_successful() {return true;}};
            processes.push(process); return process;
        }},
    };
    const mocks = {
        'gi://Clutter': {default: {Orientation: {VERTICAL: 1, HORIZONTAL: 0}, ActorAlign: {END: 1}}},
        'gi://Gio': {default: Gio},
        'gi://GLib': {default: {PRIORITY_DEFAULT: 0, SOURCE_CONTINUE: true, timeout_add_seconds(_p, interval, cb) {const entry = {interval, cb}; timers.add(entry); return entry;}, Source: {remove(entry) {timers.delete(entry);}}}},
        'gi://St': {default: {BoxLayout: Actor, Label: Actor, Icon: Actor, Button: Actor, Widget: Actor, ScrollView: Actor}},
        'resource:///org/gnome/shell/ui/main.js': {panel: {addToStatusArea(id, button) {panel.set(id, button);}}, layoutManager: {primaryMonitor: {height: 1080}}},
        'resource:///org/gnome/shell/ui/panelMenu.js': {Button: PanelButton},
        'resource:///org/gnome/shell/ui/popupMenu.js': {PopupBaseMenuItem: Actor, PopupMenuItem: Actor},
        'resource:///org/gnome/shell/extensions/extension.js': {Extension: class {
            constructor() {this.path = new URL('../extension/', import.meta.url).pathname.replace(/\/$/, ''); this.uuid = 'test';}
            getSettings() {return settings;}
            openPreferences() {}
        }},
    };
    const context = vm.createContext({TextDecoder, Intl, Date, Object, JSON, Math, Map});
    const cache = new Map();
    const linker = async (specifier, parent) => {
        if (cache.has(specifier)) return cache.get(specifier);
        let module;
        if (mocks[specifier]) {
            const exports = mocks[specifier];
            module = new vm.SyntheticModule(Object.keys(exports), function () {for (const [key, value] of Object.entries(exports)) this.setExport(key, value);}, {context});
        } else {
            const path = new URL(specifier, parent.identifier);
            module = new vm.SourceTextModule(fs.readFileSync(path, 'utf8'), {context, identifier: path.href});
        }
        cache.set(specifier, module);
        await module.link(linker); return module;
    };
    const url = new URL('../extension/extension.js', import.meta.url);
    const entry = new vm.SourceTextModule(fs.readFileSync(url, 'utf8'), {context, identifier: url.href});
    await entry.link(linker); await entry.evaluate();
    const extension = new entry.namespace.default();
    return {extension, settings, processes, timers, panel};
}

test('enable creates two indicators, timer and offline Claude history job; disable cleans up', async () => {
    const {extension, processes, timers, panel} = await loadExtension();
    extension.enable();
    assert.equal(panel.size, 2);
    assert.equal(timers.size, 1);
    assert.equal([...timers][0].interval, 300);
    assert.equal(processes.length, 2);
    assert.ok(processes[1].args.includes('--history-only'));
    assert.ok(!processes[1].args.includes('--allow-claude'));
    extension.disable();
    assert.equal(timers.size, 0);
    assert.ok(processes.every(p => p.killed && p.cancel.cancelled));
    assert.ok([...panel.values()].every(p => p.destroyed));
    for (const proc of processes) proc.callback(proc, {}); // stale completion is ignored
    assert.equal(extension._data, null);
});
test('consent replaces pending offline job, one-provider guard survives settings changes', async () => {
    const {extension, settings, processes} = await loadExtension();
    extension.enable();
    settings.set_boolean('claude-connected', true);
    assert.ok(processes[1].killed);
    assert.ok(processes[2].args.includes('--allow-claude'));
    settings.set_boolean('claude-visible', false);
    assert.equal(extension._buttons.size, 1);
    settings.set_boolean('codex-visible', false);
    assert.equal(settings.get_boolean('codex-visible'), true);
    assert.equal(extension._buttons.size, 1);
    extension.disable();
});
test('successful callback updates quota; changing language never issues a new query', async () => {
    const {extension, processes, settings} = await loadExtension();
    extension.enable();
    processes[0].callback(processes[0], {});
    assert.equal(extension._buttons.get('codex').text.text, '75%');
    settings.handler(settings, 'language');
    assert.equal(processes.length, 2);
    extension.disable();
});
