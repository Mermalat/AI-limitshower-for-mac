#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Short-lived worker. Only counters and safe errors go to stdout; no credentials or chat text."""
import argparse
import ctypes
import datetime as dt
import json
import math
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = Path(__file__).resolve().parent
PRICES = json.loads((HERE / 'prices.json').read_text())

class UsageError(Exception):
    def __init__(self, key, retry_at=0):
        self.key, self.retry_at = key, retry_at


def number(raw, key):
    value = raw.get(key, 0)
    return float(value) if isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value) and 0 <= value <= 1e15 else 0.0


def amounts(raw, provider):
    if provider == 'codex':
        total = number(raw, 'input_tokens')
        cache = min(total, number(raw, 'cached_input_tokens'))
        writes = min(total-cache, number(raw, 'cache_write_input_tokens'))
        return (total-cache-writes, cache, writes, 0, number(raw, 'output_tokens'))
    writes = number(raw, 'cache_creation_input_tokens')
    hour = min(writes, number(raw.get('cache_creation') or {}, 'ephemeral_1h_input_tokens'))
    return (number(raw, 'input_tokens'), number(raw, 'cache_read_input_tokens'), writes-hour, hour, number(raw, 'output_tokens'))


def price(model, values):
    rates = PRICES.get(model)
    if rates is None:
        rates = next((v for k, v in PRICES.items() if model.startswith(k+'-20')), None)
    if rates is None:
        return None
    i, c, o = rates
    return sum(a*b for a, b in zip(values, (i, c, i*1.25, i*2, o)))/1e6


def timestamp(text):
    return dt.datetime.fromisoformat(str(text).replace('Z', '+00:00')).astimezone()


def history(provider, now=None, roots=None):
    now = now or dt.datetime.now().astimezone()
    today = now.date()
    first = today - dt.timedelta(days=6)
    days = [{'date': (first+dt.timedelta(days=i)).isoformat(), 'tokens': 0, 'usd': 0, 'unpriced': 0} for i in range(7)]
    home = Path.home()
    if roots is None:
        config = Path(os.getenv('CODEX_HOME', home/'.codex')) if provider == 'codex' else Path(os.getenv('CLAUDE_CONFIG_DIR', home/'.claude'))
        roots = [config/'sessions', config/'archived_sessions'] if provider == 'codex' else [config/'projects']
    result = {'days': days, 'tokens': 0, 'usd': 0, 'unpriced': 0, 'available': any(p.exists() for p in roots), 'incomplete': False}
    records = {}
    for root in roots:
        if not root.exists():
            continue
        for directory, dirs, files in os.walk(root, followlinks=False):
            dirs[:] = [d for d in dirs if not (Path(directory)/d).is_symlink()]
            for name in files:
                path = Path(directory)/name
                if path.suffix != '.jsonl' or path.is_symlink():
                    continue
                previous, model, skip = (0,)*5, '', False
                try:
                    if dt.datetime.fromtimestamp(path.stat().st_mtime).astimezone().date() < first:
                        continue
                    with path.open(encoding='utf-8') as stream:
                        while True:
                            line = stream.readline(16*1024*1024)
                            if not line:
                                break
                            if not line.endswith('\n'):
                                if len(line) >= 16*1024*1024:
                                    result['incomplete'] = True
                                break
                            if provider == 'codex' and not any(key in line for key in ('token_count', 'turn_context', 'session_meta')):
                                continue
                            if provider == 'claude' and '"usage"' not in line:
                                continue
                            try:
                                row = json.loads(line)
                                if provider == 'codex':
                                    payload = row.get('payload') or {}
                                    if row.get('type') == 'session_meta':
                                        source = payload.get('source') or {}
                                        skip = isinstance(source, dict) and (source.get('subagent') or {}).get('other') == 'guardian'
                                    if row.get('type') == 'turn_context':
                                        model = payload.get('model', '')
                                    info = payload.get('info') or {}
                                    if skip or model == 'codex-auto-review' or payload.get('type') != 'token_count' or not isinstance(info.get('total_token_usage'), dict):
                                        continue
                                    current = amounts(info['total_token_usage'], provider)
                                    delta = amounts(info.get('last_token_usage') or info['total_token_usage'], provider) if sum(current) < sum(previous) else tuple(max(0, a-b) for a, b in zip(current, previous))
                                    previous = current
                                    when = timestamp(row['timestamp'])
                                    if not first <= when.date() <= today or when > now or sum(delta) <= 0:
                                        continue
                                    records[(row['timestamp'], model, current)] = (model, delta, when)
                                else:
                                    message = row.get('message') or {}
                                    if row.get('type') != 'assistant' or not isinstance(message.get('usage'), dict):
                                        continue
                                    model = message.get('model', '')
                                    identity = message.get('id') or row.get('uuid')
                                    when = timestamp(row['timestamp'])
                                    if not identity or model == '<synthetic>' or not first <= when.date() <= today or when > now:
                                        continue
                                    values = amounts(message['usage'], provider)
                                    key = (model, identity)
                                    old = records.get(key)
                                    if old:
                                        values = tuple(max(a, b) for a, b in zip(values, old[1]))
                                        when = min(when, old[2])
                                    records[key] = (model, values, when)
                            except (ValueError, TypeError, KeyError, AttributeError):
                                result['incomplete'] = True
                except (OSError, UnicodeError):
                    result['incomplete'] = True
    for model, values, when in records.values():
        day = days[(when.date()-first).days]
        day['tokens'] += sum(values)
        cost = price(model, values)
        day['usd'] += cost or 0
        day['unpriced'] += sum(values) if cost is None else 0
    for field in ('tokens', 'usd', 'unpriced'):
        result[field] = sum(day[field] for day in days)
    return result


def windows(raw, provider, plan=None):
    items = []
    if provider == 'codex':
        bucket = (raw.get('rateLimitsByLimitId') or {}).get('codex') or raw.get('rateLimits') or {}
        plan = bucket.get('planType')
        fields = [('primary', 'Kısa dönem'), ('secondary', 'Uzun dönem')]
    else:
        bucket = raw
        fields = [('five_hour', '5 saatlik'), ('seven_day', 'Haftalık'), ('seven_day_sonnet', 'Sonnet · haftalık'), ('seven_day_opus', 'Opus · haftalık')]
    for key, title in fields:
        value = bucket.get(key)
        if not isinstance(value, dict):
            continue
        used = value.get('usedPercent' if provider == 'codex' else 'utilization')
        if isinstance(used, bool) or not isinstance(used, (int, float)) or not math.isfinite(used) or used < 0:
            continue
        if provider == 'codex':
            minutes = number(value, 'windowDurationMins')
            if minutes > 525600:
                continue
            if minutes >= 10080:
                title = 'Haftalık'
            elif minutes >= 60:
                title = f'{int(minutes/60)} saatlik'
            elif minutes:
                title = f'{int(minutes)} dakikalık'
            reset = value.get('resetsAt')
            reset = reset if isinstance(reset, (int, float)) and not isinstance(reset, bool) and math.isfinite(reset) else None
        else:
            try:
                reset = timestamp(value.get('resets_at')).timestamp()
            except (ValueError, TypeError):
                reset = None
        items.append({'id': key, 'title': title, 'remaining': max(0, min(100, 100-used)), 'used': used, 'reset': reset})
    if not items:
        raise UsageError('Codex bu hesap için limit yüzdesi döndürmedi.' if provider == 'codex' else 'Claude bu hesap için limit yüzdesi döndürmedi.')
    remaining = min((w['remaining'] for w in items if w['id'] in ('primary', 'secondary', 'five_hour', 'seven_day')), default=None)
    return {'windows': items, 'remaining': remaining, 'plan': plan, 'updated': time.time()}


def child_death_signal():
    # The Codex child must not survive a forcibly stopped extension worker on Linux.
    if sys.platform.startswith('linux'):
        ctypes.CDLL(None).prctl(1, signal.SIGKILL)
        if os.getppid() == 1:
            os._exit(1)


def codex(path=''):
    choices = [Path(path)] if path else [Path.home()/'.local/bin/codex', Path('/usr/local/bin/codex'), Path('/usr/bin/codex')]
    executable = next((str(p) for p in choices if p.is_absolute() and p.is_file() and os.access(p, os.X_OK)), None)
    if not executable:
        raise UsageError('Codex bulunamadı. Önce Codex CLI kurup ChatGPT hesabınla giriş yap.')
    proc = subprocess.Popen([executable, 'app-server', '-c', 'analytics.enabled=false'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, preexec_fn=child_death_signal)
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    buffer, deadline = bytearray(), time.monotonic()+25
    def send(value):
        proc.stdin.write(json.dumps(value).encode()+b'\n')
        proc.stdin.flush()
    def receive(identity):
        while time.monotonic() < deadline:
            while b'\n' in buffer:
                line, _, rest = buffer.partition(b'\n')
                buffer[:] = rest
                row = json.loads(line)
                if row.get('id') != identity:
                    continue
                if not isinstance(row.get('result'), dict):
                    raise UsageError('Codex limitleri okunamadı. Terminal’de codex login ile oturumunu kontrol et.')
                return row['result']
            if selector.select(max(0, deadline-time.monotonic())):
                chunk = os.read(proc.stdout.fileno(), 8192)
                if not chunk:
                    raise UsageError('Codex bağlantısı kapandı. Codex kurulumunu ve oturumunu kontrol et.')
                buffer.extend(chunk)
                if len(buffer) > 1048576:
                    raise UsageError('Yerel uygulamadan beklenmeyen yanıt geldi.')
        raise UsageError('Bağlantı zaman aşımına uğradı. Tekrar dene.')
    try:
        send({'id': 1, 'method': 'initialize', 'params': {'clientInfo': {'name': 'ai_limits_gnome', 'version': '1.0.0'}}})
        receive(1)
        send({'method': 'initialized'})
        send({'id': 2, 'method': 'account/rateLimits/read'})
        return windows(receive(2), 'codex')
    finally:
        selector.close()
        proc.stdin.close()
        if proc.poll() is None:
            proc.terminate()
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        proc.stdout.close()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def credentials(path=None):
    config = Path(os.getenv('CLAUDE_CONFIG_DIR', Path.home()/'.claude'))
    file = Path(path) if path else config/'.credentials.json'
    try:
        size = file.stat().st_size
    except OSError:
        raise UsageError('Claude Code oturumu yok. Terminal’de claude açıp /login çalıştır.') from None
    if size > 1048576:
        raise UsageError('Claude Code oturumu yok. Terminal’de claude açıp /login çalıştır.')
    oauth = json.loads(file.read_text()).get('claudeAiOauth') or {}
    token = oauth.get('accessToken')
    if not isinstance(token, str) or not token or '\n' in token or '\r' in token:
        raise UsageError('Claude Code oturumu yok. Terminal’de claude açıp /login çalıştır.')
    if number(oauth, 'expiresAt') and number(oauth, 'expiresAt')/1000 <= time.time():
        raise UsageError('Claude oturumu süresi doldu. Claude Code’u açarak oturumu yenile, sonra tekrar dene.')
    if 'scopes' in oauth and 'user:profile' not in oauth['scopes']:
        raise UsageError('Claude oturumunda kullanım okuma izni yok. Claude Code’da /login ile tekrar giriş yap.')
    return token, oauth.get('subscriptionType')


def claude(allowed=False):
    if not allowed:
        raise UsageError('Bağlı değil')
    token, plan = credentials()
    request = urllib.request.Request('https://api.anthropic.com/api/oauth/usage', headers={'Authorization': 'Bearer '+token, 'anthropic-beta': 'oauth-2025-04-20', 'Accept': 'application/json'})
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=25) as response:
            data = response.read(1048577)
            if len(data) > 1048576:
                raise UsageError('Claude’dan geçersiz yanıt geldi.')
            return windows(json.loads(data), 'claude', plan)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            try:
                seconds = float(error.headers.get('Retry-After', '300'))
            except ValueError:
                seconds = 300
            if not math.isfinite(seconds):
                seconds = 300
            raise UsageError('Sunucu çok sık sorgulandı. Bir süre sonra otomatik tekrar denenecek.', time.time()+max(300, seconds)) from None
        raise UsageError('Claude oturumu kabul edilmedi. Claude Code’da /login ile oturumunu yenile.' if error.code in (401, 403) else 'Claude’a ulaşılamadı. İnternet bağlantını kontrol et.') from None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--provider', choices=['codex', 'claude'], required=True)
    parser.add_argument('--history', action='store_true')
    parser.add_argument('--history-only', action='store_true')
    parser.add_argument('--allow-claude', action='store_true')
    parser.add_argument('--codex-path', default='')
    args = parser.parse_args()
    result = {}
    if not args.history_only:
        try:
            result['snapshot'] = codex(args.codex_path) if args.provider == 'codex' else claude(args.allow_claude)
        except UsageError as error:
            result.update(error=error.key, retryAt=error.retry_at)
        except Exception:
            result['error'] = 'Veri okunamadı. Tekrar dene.'
    if args.history:
        try:
            result['history'] = history(args.provider)
        except Exception:
            result['history'] = {'available': False, 'incomplete': True, 'days': []}
    print(json.dumps(result, ensure_ascii=False, allow_nan=False))

if __name__ == '__main__':
    main()
