#!/usr/bin/env python3
"""Warm Bitrix composite cache from sitemap.xml with server load throttling."""
import argparse
import gzip
import logging
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

USER_AGENT = 'Mozilla/5.0 (compatible; BitrixCacheWarmup/1.0)'


def host(url):
    return urllib.parse.urlsplit(url).hostname


def fetch(url, timeout, *, xml=False):
    request = urllib.request.Request(url, headers={
        'User-Agent': USER_AGENT,
        'Accept': 'application/xml,text/xml,*/*' if xml else 'text/html,application/xhtml+xml,*/*',
    })
    with urllib.request.urlopen(request, timeout=timeout) as response:
        final_url = response.geturl()
        if host(final_url) != host(url):
            raise ValueError(f'External redirect blocked: {final_url}')
        status = response.status
        composite = response.headers.get('X-Bitrix-Composite', '-')
        if xml:
            data = response.read(52_428_801)
            if len(data) > 52_428_800:
                raise ValueError('Sitemap exceeds 50 MiB (compressed body)')
            if final_url.lower().endswith('.gz') or data.startswith(b'\x1f\x8b'):
                data = gzip.decompress(data)
                if len(data) > 100_000_000:
                    raise ValueError('Sitemap XML too large')
            return data
        while response.read(65536):
            pass
        return status, composite


def sitemap_urls(start, timeout):
    pending = [start]
    visited = set()
    pages = set()
    origin_host = host(start)
    while pending:
        sitemap = pending.pop()
        if sitemap in visited:
            continue
        visited.add(sitemap)
        if host(sitemap) != origin_host:
            logging.warning('Skipping external sitemap %s', sitemap)
            continue
        logging.info('Reading sitemap %s', sitemap)
        root = ET.fromstring(fetch(sitemap, timeout, xml=True))
        root_type = root.tag.split('}')[-1]
        if root_type not in ('sitemapindex', 'urlset'):
            raise ValueError(f'Unexpected XML root in {sitemap}: {root.tag}')
        for item in root:
            if item.tag.split('}')[-1] not in ('url', 'sitemap'):
                continue
            loc = next((child.text.strip() for child in item
                        if child.tag.split('}')[-1] == 'loc' and child.text), None)
            if not loc:
                continue
            loc = urllib.parse.urljoin(sitemap, loc)
            parts = urllib.parse.urlsplit(loc)
            if parts.scheme not in ('http', 'https') or host(loc) != origin_host:
                logging.warning('Skipping external URL %s', loc)
                continue
            if root_type == 'sitemapindex':
                pending.append(loc)
            elif not parts.query and not parts.fragment:
                pages.add(loc)
    return sorted(pages)


def wait_for_load(limit, interval):
    while True:
        load = os.getloadavg()[0]
        if load <= limit:
            return load
        logging.warning('LA 1m %.2f > %.2f; sleeping %.0fs', load, limit, interval)
        time.sleep(interval)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sitemap', help='Full sitemap URL, e.g. https://example.com/sitemap.xml')
    parser.add_argument('--max-load', type=float, default=8.0)
    parser.add_argument('--delay', type=float, default=5.0)
    parser.add_argument('--load-wait', type=float, default=30.0)
    parser.add_argument('--timeout', type=float, default=30.0)
    parser.add_argument('--retries', type=int, default=2, help='Additional attempts on failure')
    parser.add_argument('--state', type=Path, default=Path('bitrix-warmup.done'))
    parser.add_argument('--failed', type=Path, default=Path('bitrix-warmup.failed'))
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')
    if min(args.max_load, args.delay, args.load_wait, args.timeout) <= 0 or args.retries < 0:
        parser.error('Thresholds must be > 0; retries must be >= 0')
    if urllib.parse.urlsplit(args.sitemap).scheme not in ('https', 'http'):
        parser.error('Sitemap must be HTTP(S) URL')

    pages = sitemap_urls(args.sitemap, args.timeout)
    done = set(args.state.read_text().splitlines()) if args.state.exists() else set()
    remaining = [url for url in pages if url not in done]
    logging.info('Pages: %d; already done: %d; remaining: %d', len(pages), len(pages)-len(remaining), len(remaining))
    ok = failed = 0
    args.state.parent.mkdir(parents=True, exist_ok=True)
    args.failed.parent.mkdir(parents=True, exist_ok=True)
    with args.state.open('a', buffering=1) as done_file, args.failed.open('a', buffering=1) as failed_file:
        for i, url in enumerate(remaining, 1):
            if i > 1:
                time.sleep(args.delay)
            for attempt in range(args.retries + 1):
                la = wait_for_load(args.max_load, args.load_wait)
                started = time.monotonic()
                try:
                    status, composite = fetch(url, args.timeout)
                    if status != 200:
                        raise ValueError(f'HTTP {status}')
                    done_file.write(url + '\n')
                    ok += 1
                    logging.info('[%d/%d] HTTP %d | LA %.2f | %.2fs | Composite: %s | %s',
                                 i, len(remaining), status, la, time.monotonic()-started, composite, url)
                    break
                except urllib.error.HTTPError as exc:
                    if exc.code == 404:
                        logging.warning('[%d/%d] HTTP 404 (no retry) | %s', i, len(remaining), url)
                        failed_file.write(url + '\n')
                        failed += 1
                        break
                    logging.warning('[%d/%d] attempt %d/%d failed: HTTP %d | %s',
                                    i, len(remaining), attempt+1, args.retries+1, exc.code, url)
                    if attempt < args.retries:
                        time.sleep(max(args.delay, 5.0))
                except (urllib.error.URLError, ValueError, TimeoutError, OSError) as exc:
                    logging.warning('[%d/%d] attempt %d/%d failed: %s | %s',
                                    i, len(remaining), attempt+1, args.retries+1, exc, url)
                    if attempt < args.retries:
                        time.sleep(max(args.delay, 5.0))
            else:
                failed_file.write(url + '\n')
                failed += 1
    logging.info('Finished: successful=%d, failed=%d, skipped(previously done)=%d',
                 ok, failed, len(pages)-len(remaining))
    return 1 if failed else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        logging.warning('Interrupted; progress saved')
        sys.exit(130)
