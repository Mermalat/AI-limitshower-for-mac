// SPDX-License-Identifier: GPL-3.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {canHide, translate, graphHeights, LANGUAGES, locale, quotaColor} from '../extension/logic.js';
const catalog = JSON.parse(fs.readFileSync(new URL('../extension/translations.json', import.meta.url)));
test('one provider must remain visible', () => {
    assert.equal(canHide('codex', {codex: true, claude: false}), false);
    assert.equal(canHide('claude', {codex: true, claude: true}), true);
});
test('all seven languages and format placeholders', () => {
    for (const language of LANGUAGES) {
        assert.ok(locale(language));
        assert.match(translate('%d dakikada bir güncellenir', language, catalog, 7), /7/);
        assert.ok(!translate('%@ göster', language, catalog, 'Codex').includes('%@'));
    }
    assert.equal(translate('%d %% %@', 'tr', catalog, 5, 'left'), '5 % left');
    for (const values of Object.values(catalog)) assert.equal(values.length, 6);
});
test('seven bars use a shared scale including empty days', () => {
    assert.deepEqual(graphHeights([{tokens: 0}, {tokens: 50}, {tokens: 100}]), [2, 40, 80]);
    assert.deepEqual(graphHeights([{tokens: 0}]), [2]);
});
test('every literal UI message has translations', () => {
    for (const file of ['extension.js', 'prefs.js']) {
        const source = fs.readFileSync(new URL(`../extension/${file}`, import.meta.url), 'utf8');
        for (const [, key] of source.matchAll(/(?:this\._t|\bt)\('([^']+)'/g))
            assert.ok(catalog[key], `missing ${file}: ${key}`);
    }
});

test('quota warnings match the macOS thresholds', () => {
    assert.equal(quotaColor('codex', 10), '#f05b57');
    assert.equal(quotaColor('claude', 30), '#ffab3d');
    assert.equal(quotaColor('claude', 31), '#cc7857');
});
