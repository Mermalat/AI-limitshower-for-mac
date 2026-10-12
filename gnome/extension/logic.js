// SPDX-License-Identifier: GPL-3.0-only
export const PROVIDERS = ['codex', 'claude'];
export const LANGUAGES = ['tr', 'en', 'es', 'ja', 'zh', 'de', 'fr'];
export function canHide(provider, visible) {
    return visible[PROVIDERS.find(p => p !== provider)];
}
export function translate(key, language, catalog, ...args) {
    let value = language === 'tr' ? key : catalog[key]?.[LANGUAGES.indexOf(language) - 1] ?? key;
    return value.replace(/%%|%@|%d/g, match => match === '%%' ? '%' : String(args.shift() ?? ''));
}
export function locale(language) {
    return {tr: 'tr-TR', en: 'en-US', es: 'es-ES', ja: 'ja-JP', zh: 'zh-CN', de: 'de-DE', fr: 'fr-FR'}[language] ?? 'en-US';
}
export function graphHeights(days, maximum = 80) {
    const peak = Math.max(1, ...days.map(day => day.tokens));
    return days.map(day => Math.max(2, Math.round(maximum * day.tokens / peak)));
}

export function quotaColor(provider, remaining) {
    if (remaining <= 10) return '#f05b57';
    if (remaining <= 30) return '#ffab3d';
    return provider === 'codex' ? '#2eaa7d' : '#cc7857';
}
