#!/usr/bin/env python3
"""Bitrix composite cache warmup from sitemap: SQLite, nginx access priorities, LA/RAM throttling.

Python >= 3.9; only standard library. One worker; no simultaneous page requests.
"""
import argparse
import datetime as dt
import email.utils
import gzip
import glob
import io
import logging
import os
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

AGENT = 'Mozilla/5.0 (compatible; BitrixCacheWarmup/2.0)'
# Standard nginx combined log: request, status, referrer, user-agent.
# Handles escaped quotes within quoted fields.
_QUOTED = r'"(?:[^"\\]|\\.)*"'
LOG_RE = re.compile(
    r'^\S+\s+\S+\s+\S+\s+\[[^]]+\]\s+'
    r'"(?P<method>GET|HEAD)\s+(?P<target>\S+)\s+HTTP/\d+(?:\.\d+)?"\s+'
    r'(?P<status>\d{3})\s+\S+\s+' + _QUOTED + r'\s+"(?P<ua>(?:[^"\\]|\\.)*)"'
)
# Heuristic for prioritization only; excludes known bot identifiers and typical
# scraper/monitoring tools, but cannot reliably identify spoofed browser UAs.
BOT_UA_RE = re.compile(
    r'bot|crawl|spider|slurp|fetch|scrap|monitor|uptime|healthcheck|'
    r'headless|lighthouse|pagespeed|python-requests|python-urllib|'
    r'curl/|wget/|libwww-perl|httpclient|aiohttp|go-http-client|'
    r'axios/|node-fetch|postman|semrush|ahrefs|mj12|bytespider|'
    r'facebookexternalhit|twitterbot|telegrambot|discordbot|'
    r'bitrixcloud|yandexmetrika', re.IGNORECASE
)


def host(url):
    return (urllib.parse.urlsplit(url).hostname or '').lower()


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if host(newurl) != host(req.full_url) or urllib.parse.urlsplit(newurl).scheme not in ('http', 'https'):
            raise ValueError('External redirect blocked: ' + newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


OPENER = urllib.request.build_opener(SafeRedirect())


def get(url, timeout, xml=False):
    req = urllib.request.Request(url, headers={
        'User-Agent': AGENT,
        'Accept': 'application/xml,text/xml,*/*' if xml else 'text/html,application/xhtml+xml,*/*',
        'Accept-Encoding': 'identity',
    })
    with OPENER.open(req, timeout=timeout) as resp:
        if host(resp.geturl()) != host(url):
            raise ValueError('Redirect to external host')
        if xml:
            raw = resp.read(52_428_801)
            if len(raw) > 52_428_800:
                raise ValueError('Sitemap compressed/body size exceeds 50 MiB')
            if raw.startswith(b'\x1f\x8b') or resp.geturl().lower().endswith('.gz'):
                with gzip.GzipFile(fileobj=io.BytesIO(raw)) as gz:
                    raw = gz.read(100_000_001)
                if len(raw) > 100_000_000:
                    raise ValueError('Uncompressed sitemap exceeds 100 MB')
            return raw
        while resp.read(65536):
            pass
        return resp.status, resp.headers.get('X-Bitrix-Composite', '-'), resp.geturl()


def child_text(elem, name):
    return next((child.text.strip() for child in elem if child.tag.split('}')[-1] == name and child.text), None)


def parsed_lastmod(value):
    if not value:
        return None
    try:
        d = dt.datetime.fromisoformat(value.strip().replace('Z', '+00:00'))
        if d.tzinfo is None:
            d = d.replace(tzinfo=dt.timezone.utc)
        return d.timestamp()
    except (ValueError, OverflowError):
        return None


def init_db(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(str(path))
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('PRAGMA busy_timeout=10000')
    db.executescript('''
        CREATE TABLE IF NOT EXISTS pages (
            url TEXT PRIMARY KEY,
            lastmod TEXT,
            lastmod_ts REAL,
            status TEXT NOT NULL DEFAULT 'pending',
            http_code INTEGER,
            composite TEXT,
            last_success REAL,
            last_attempt REAL,
            duration_ms INTEGER,
            hits INTEGER NOT NULL DEFAULT 0,
            scan_id INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_pages_scan_status_hits ON pages(scan_id,status,hits DESC);
        CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
    ''')
    db.commit()
    return db


def import_legacy(db, state):
    flag = db.execute("SELECT 1 FROM meta WHERE key='legacy_imported'").fetchone()
    if flag:
        return
    if state.exists():
        num = 0
        with state.open(encoding='utf-8', errors='replace') as f:
            for line in f:
                url = line.strip()
                if url.startswith(('https://', 'http://')):
                    db.execute("INSERT INTO pages(url,status) VALUES(?,'done') ON CONFLICT(url) DO UPDATE SET status='done'", (url,))
                    num += 1
        logging.info('Imported %d legacy .done lines into SQLite', num)
    db.execute("INSERT INTO meta(key,value) VALUES('legacy_imported','1')")
    db.commit()


def load_sitemaps(db, start, timeout, scan_id):
    pending, visited, count = [start], set(), 0
    origin = host(start)
    while pending:
        sitemap = pending.pop()
        if sitemap in visited:
            continue
        visited.add(sitemap)
        if host(sitemap) != origin:
            logging.warning('Skipping external sitemap %s', sitemap)
            continue
        logging.info('Reading sitemap %s', sitemap)
        root = ET.fromstring(get(sitemap, timeout, xml=True))
        kind = root.tag.split('}')[-1]
        if kind not in ('sitemapindex', 'urlset'):
            raise ValueError('Unexpected sitemap root: ' + root.tag)
        for elem in root:
            if elem.tag.split('}')[-1] != ('sitemap' if kind == 'sitemapindex' else 'url'):
                continue
            loc = child_text(elem, 'loc')
            if not loc:
                continue
            url = urllib.parse.urljoin(sitemap, loc)
            parts = urllib.parse.urlsplit(url)
            if parts.scheme not in ('http', 'https') or host(url) != origin:
                continue
            if kind == 'sitemapindex':
                pending.append(url)
            elif not parts.query and not parts.fragment:
                lm = child_text(elem, 'lastmod')
                ts = parsed_lastmod(lm)
                db.execute('''INSERT INTO pages(url,lastmod,lastmod_ts,scan_id) VALUES(?,?,?,?)
                    ON CONFLICT(url) DO UPDATE SET
                    status=CASE WHEN excluded.lastmod IS NOT NULL AND pages.lastmod IS NOT NULL
                                    AND excluded.lastmod != pages.lastmod THEN 'pending'
                                ELSE pages.status END,
                    lastmod=excluded.lastmod,lastmod_ts=excluded.lastmod_ts,scan_id=excluded.scan_id''',
                    (url, lm, ts, scan_id))
                count += 1
                if count % 5000 == 0:
                    db.commit()
        db.commit()
    return count, len(visited)


def expand_access_logs(groups):
    """Accept paths, shell-expanded names and quoted glob patterns; deduplicate."""
    paths = []
    seen = set()
    for group in groups or []:
        for pattern in group:
            matches = sorted(glob.glob(pattern)) if glob.has_magic(pattern) else [pattern]
            if not matches:
                logging.warning('No access logs match: %s', pattern)
            for name in matches:
                path = Path(name)
                if not path.is_file():
                    logging.warning('Access log missing or not a file: %s', path)
                    continue
                identity = str(path.resolve())
                if identity not in seen:
                    seen.add(identity)
                    paths.append(path)
    return paths


def update_hits(db, log_groups, site_host, scan_id, include_bots=False):
    paths = expand_access_logs(log_groups)
    if not paths:
        if log_groups:
            logging.warning('No readable access logs found; all hit priorities remain 0')
        return

    total = accepted = bot_skipped = other_skipped = 0
    # Aggregate per-path hits in bounded chunks rather than running an SQL UPDATE
    # for every line (which becomes slow on large, multi-file log archives).
    from collections import Counter
    counts = Counter()

    def flush():
        if not counts:
            return
        db.executemany(
            'UPDATE pages SET hits=hits+? WHERE scan_id=? AND url IN (?,?)',
            ((hits, scan_id, 'https://' + site_host + path,
              'http://' + site_host + path) for path, hits in counts.items())
        )
        db.commit()
        counts.clear()

    for path in paths:
        file_total = file_accepted = file_bots = 0
        opener = gzip.open if path.name.lower().endswith('.gz') else open
        try:
            with opener(path, 'rt', encoding='utf-8', errors='replace') as f:
                for line in f:
                    total += 1
                    file_total += 1
                    m = LOG_RE.search(line)
                    if not m or m.group('method') != 'GET' or m.group('status') != '200':
                        other_skipped += 1
                        continue
                    ua = m.group('ua')
                    if not include_bots and (not ua or ua == '-' or BOT_UA_RE.search(ua)):
                        bot_skipped += 1
                        file_bots += 1
                        continue
                    target = m.group('target')
                    if target.startswith(('http://', 'https://')):
                        p = urllib.parse.urlsplit(target)
                        if host(target) != site_host:
                            other_skipped += 1
                            continue
                        target = p.path + (('?' + p.query) if p.query else '')
                    if not target.startswith('/') or '?' in target or '#' in target:
                        other_skipped += 1
                        continue
                    counts[target] += 1
                    accepted += 1
                    file_accepted += 1
                    if len(counts) >= 10000:
                        flush()
        except (OSError, EOFError, gzip.BadGzipFile) as exc:
            logging.warning('Unable to fully read access log %s: %s', path, exc)
        flush()
        logging.info('Access log %s: lines=%d, prioritized requests=%d, bot requests skipped=%d',
                     path, file_total, file_accepted, file_bots)
    logging.info('Access priority: files=%d, lines=%d, accepted GET 200=%d, bots excluded=%d, other excluded=%d',
                 len(paths), total, accepted, bot_skipped, other_skipped)


def mem_available_mb():
    try:
        with open('/proc/meminfo', encoding='ascii') as f:
            for line in f:
                if line.startswith('MemAvailable:'):
                    return int(line.split()[1]) / 1024
    except (OSError, ValueError, IndexError):
        pass
    return None


def wait_resources(args):
    while True:
        la = os.getloadavg()[0]
        avail = mem_available_mb()
        low_ram = args.min_mem_mb > 0 and avail is not None and avail < args.min_mem_mb
        if la <= args.max_load and not low_ram:
            return la, avail
        logging.warning('Throttle: LA=%.2f (max %.2f), MemAvailable=%s MB (min %.0f); sleep %.0fs',
                        la, args.max_load, 'unknown' if avail is None else str(round(avail)),
                        args.min_mem_mb, args.load_wait)
        time.sleep(args.load_wait)


def delay_for_load(args, la):
    if not args.adaptive_delay:
        return args.delay
    # Delay is never greater than the user's original --delay at low LA; max 2x under load.
    ratio = la / args.max_load
    if ratio <= .25:
        return max(.5, args.delay * .1)
    if ratio <= .5:
        return max(1., args.delay * .2)
    if ratio <= .75:
        return max(2., args.delay * .4)
    if ratio <= .875:
        return args.delay
    return args.delay * 2


def cache_file(cache_root, url):
    """Typical Bitrix nginx file-cache path. Never use for URLs with query/unsafe segments."""
    p = urllib.parse.urlsplit(url)
    if p.query or p.fragment or not p.hostname:
        return None
    path = urllib.parse.unquote(p.path)
    if '\\' in path or '\x00' in path or any(x in ('.', '..') for x in path.split('/')):
        return None
    # PHP cache paths depend on nginx rewrite rules; avoid unsafe assumptions.
    if path.lower().endswith('.php'):
        return None
    segments = [s for s in path.split('/') if s]
    if not segments or path.endswith('/'):
        rel = Path(p.hostname.lower(), *segments, 'index@.html')
    else:
        rel = Path(p.hostname.lower(), *segments[:-1], segments[-1] + '@.html')
    root = cache_root.resolve()
    candidate = (root / rel).resolve()
    if not candidate.is_relative_to(root):
        return None
    return candidate


def file_cache_fresh(path, lastmod_ts, max_age_days):
    if path is None:
        return False
    try:
        st = path.stat()
    except OSError:
        return False
    if not path.is_file() or st.st_size <= 0:
        return False
    if lastmod_ts is not None and st.st_mtime < lastmod_ts:
        return False
    if max_age_days > 0 and time.time() - st.st_mtime > max_age_days * 86400:
        return False
    return True


def retry_after_secs(err):
    raw = err.headers.get('Retry-After', '')
    if raw.isdigit():
        return float(raw)
    try:
        d = email.utils.parsedate_to_datetime(raw)
        return max(0., d.timestamp() - time.time())
    except (ValueError, TypeError, OverflowError):
        return 0.


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('sitemap', help='Full sitemap URL, e.g. https://example.com/sitemap.xml')
    parser.add_argument('--max-load', type=float, default=8.0)
    parser.add_argument('--delay', type=float, default=5.0, help='Base pause between page requests')
    parser.add_argument('--adaptive-delay', action='store_true', help='Adjust delay according to LA')
    parser.add_argument('--load-wait', type=float, default=30.0)
    parser.add_argument('--min-mem-mb', type=float, default=1024, help='Minimum Linux MemAvailable in MiB; 0 disables')
    parser.add_argument('--timeout', type=float, default=30.0)
    parser.add_argument('--retries', type=int, default=2, help='Additional attempts on failure')
    parser.add_argument('--backoff-max', type=float, default=300, help='Maximum wait after 429/503')
    parser.add_argument('--state', type=Path, default=Path('bitrix-warmup.done'), help='Legacy success log; imported into SQLite')
    parser.add_argument('--failed', type=Path, default=Path('bitrix-warmup.failed'))
    parser.add_argument('--db', type=Path, default=Path('bitrix-warmup.sqlite3'))
    parser.add_argument('--access-log', nargs='+', action='append', metavar='PATH',
                        help='One or more nginx combined access logs; accepts .gz and glob patterns. Can be repeated')
    parser.add_argument('--include-bots', action='store_true',
                        help='Also count bot/monitoring user-agents in access priorities (off by default)')
    parser.add_argument('--cache-dir', type=Path, help='Directory .../bitrix/html_pages (optional file-cache check)')
    parser.add_argument('--cache-max-age-days', type=float, default=0, help='0 = do not check file age')
    parser.add_argument('--refresh-days', type=float, default=0, help='Revisit successful pages after N days; 0 = incremental only')
    parser.add_argument('--full', action='store_true', help='Revisit all pages, overriding prior status')
    parser.add_argument('--limit', type=int, default=0, help='Maximum page URLs this run; 0 = unlimited')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
    if args.max_load <= 0 or args.delay <= 0 or args.load_wait <= 0 or args.timeout <= 0 or args.retries < 0 or args.backoff_max <= 0 or args.min_mem_mb < 0 or args.refresh_days < 0 or args.cache_max_age_days < 0 or args.limit < 0:
        parser.error('Invalid non-positive threshold or negative count')
    if urllib.parse.urlsplit(args.sitemap).scheme not in ('https','http') or not host(args.sitemap):
        parser.error('Sitemap must be HTTP(S) URL')
    if args.cache_dir and not args.cache_dir.is_dir():
        parser.error('--cache-dir must be an existing directory')
    db = init_db(args.db)
    import_legacy(db, args.state)
    scan_id = int(time.time_ns())
    seen, maps = load_sitemaps(db, args.sitemap, args.timeout, scan_id)
    # File cache must be rechecked after each scan: files may have been removed.
    db.execute("UPDATE pages SET status='pending' WHERE scan_id=? AND status='cached'", (scan_id,))
    db.execute('UPDATE pages SET hits=0 WHERE scan_id=?', (scan_id,))
    db.commit()
    update_hits(db, args.access_log, host(args.sitemap), scan_id, args.include_bots)
    if args.full:
        db.execute("UPDATE pages SET status='pending' WHERE scan_id=?", (scan_id,))
    elif args.refresh_days:
        cutoff = time.time() - args.refresh_days * 86400
        db.execute("UPDATE pages SET status='pending' WHERE scan_id=? AND status='done' AND last_success < ?", (scan_id, cutoff))
    db.commit()
    total = db.execute('SELECT COUNT(*) FROM pages WHERE scan_id=?', (scan_id,)).fetchone()[0]
    completed = db.execute("SELECT COUNT(*) FROM pages WHERE scan_id=? AND status IN ('done','not_found','cached')", (scan_id,)).fetchone()[0]
    logging.info('Sitemap records=%d, unique=%d, sitemap files=%d, already processed=%d, pending=%d',
                 seen, total, maps, completed, total-completed)
    args.state.parent.mkdir(parents=True, exist_ok=True)
    args.failed.parent.mkdir(parents=True, exist_ok=True)
    query = "SELECT url,lastmod_ts,hits FROM pages WHERE scan_id=? AND status NOT IN ('done','not_found','cached') ORDER BY hits DESC, COALESCE(lastmod_ts,0) DESC, url"
    if args.limit:
        query += ' LIMIT ' + str(args.limit)
    # Separate cursor allows writes while iterating the selected URLs.
    rows = db.execute(query, (scan_id,))
    ok = failures = cached = not_found = 0
    prev_request_at = None
    with args.state.open('a', buffering=1, encoding='utf-8') as done_file, args.failed.open('a', buffering=1, encoding='utf-8') as failed_file:
        for i, (url, lastmod_ts, hits) in enumerate(rows, 1):
            if args.cache_dir:
                path = cache_file(args.cache_dir, url)
                if file_cache_fresh(path, lastmod_ts, args.cache_max_age_days):
                    db.execute("UPDATE pages SET status='cached',http_code=NULL,composite='file',last_success=? WHERE url=?", (time.time(), url))
                    db.commit()
                    cached += 1
                    if i % 1000 == 0:
                        logging.info('[%d] skipped %d cache files; %s', i, cached, url)
                    continue
            la, mem = wait_resources(args)
            delay = delay_for_load(args, la)
            if prev_request_at is not None:
                time.sleep(max(0, delay - (time.monotonic() - prev_request_at)))
            for attempt in range(args.retries + 1):
                la, mem = wait_resources(args)
                started = time.monotonic()
                prev_request_at = started
                code = None
                try:
                    code, composite, final = get(url, args.timeout)
                    if code != 200:
                        raise ValueError('HTTP ' + str(code))
                    duration = round((time.monotonic() - started) * 1000)
                    now = time.time()
                    db.execute("UPDATE pages SET status='done',http_code=200,composite=?,last_success=?,last_attempt=?,duration_ms=? WHERE url=?",
                               (composite, now, now, duration, url))
                    db.commit()
                    done_file.write(url + '\n')
                    ok += 1
                    logging.info('[%d] HTTP 200 | LA %.2f | RAM %s MB | %.2fs | hits %d | Composite %s | %s',
                                 i, la, '-' if mem is None else round(mem), duration / 1000, hits, composite, url)
                    break
                except urllib.error.HTTPError as exc:
                    code = exc.code
                    if code == 404:
                        db.execute("UPDATE pages SET status='not_found',http_code=404,last_attempt=? WHERE url=?", (time.time(), url))
                        db.commit()
                        failed_file.write('404 ' + url + '\n')
                        not_found += 1
                        logging.warning('[%d] HTTP 404 (no retries) | %s', i, url)
                        break
                    logging.warning('[%d] HTTP %d, attempt %d/%d | %s', i, code, attempt + 1, args.retries + 1, url)
                    if attempt < args.retries:
                        pause = min(args.backoff_max, max(args.delay, 5) * (2 ** attempt))
                        if code in (429,503):
                            pause = min(args.backoff_max, max(pause, retry_after_secs(exc)))
                        time.sleep(pause)
                except (urllib.error.URLError, ValueError, TimeoutError, OSError) as exc:
                    logging.warning('[%d] %s, attempt %d/%d | %s', i, exc, attempt + 1, args.retries + 1, url)
                    if attempt < args.retries:
                        time.sleep(min(args.backoff_max, max(args.delay, 5) * (2 ** attempt)))
            else:
                db.execute("UPDATE pages SET status='failed',http_code=?,last_attempt=? WHERE url=?", (code, time.time(), url))
                db.commit()
                failed_file.write(str(code or 'ERROR') + ' ' + url + '\n')
                failures += 1
    logging.info('Finished: HTTP200=%d, cached files=%d, HTTP404=%d, other failures=%d, previously processed=%d',
                 ok, cached, not_found, failures, completed)
    db.close()
    return 1 if failures else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        logging.warning('Interrupted; SQLite progress retained')
        sys.exit(130)
