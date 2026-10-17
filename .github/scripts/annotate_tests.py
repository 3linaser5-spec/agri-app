#!/usr/bin/env python3
"""Turn `flutter test --reporter json` output into GitHub annotations.

Failed tests (and test files that do not even compile) become error
annotations that can be read through the API without opening the job log.
GitHub keeps at most 10 error annotations per step, so only the first 10
problems are reported; the summary line carries the real counts.

Usage: annotate_tests.py <test.json>
"""
import json
import os
import sys

MAX_ANNOTATIONS = 10

tests = {}      # id -> test info from "testStart"
problems = []   # "error" events
total = passed = 0

with open(sys.argv[1], encoding='utf-8', errors='replace') as fh:
    for raw in fh:
        raw = raw.strip()
        if not raw.startswith('{'):
            continue
        try:
            ev = json.loads(raw)
        except ValueError:
            continue
        kind = ev.get('type')
        if kind == 'testStart':
            info = ev.get('test') or {}
            tests[info.get('id')] = info
        elif kind == 'error':
            problems.append(ev)
        elif kind == 'testDone' and not ev.get('hidden'):
            total += 1
            if ev.get('result') == 'success':
                passed += 1


def relative(url):
    if not url:
        return ''
    path = url[7:] if url.startswith('file://') else url
    try:
        return os.path.relpath(path)
    except ValueError:
        return path


for ev in problems[:MAX_ANNOTATIONS]:
    info = tests.get(ev.get('testID'), {})
    name = info.get('name') or 'test'
    file = relative(info.get('url')) or 'test'
    line = info.get('line') or 1
    message = f"{name}: {ev.get('error', '')}".strip()
    message = message[:600]
    message = message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print(f'::error file={file},line={line},title=test failed::{message}')

print(f'tests: {passed} passed of {total}, {len(problems)} problem(s)')
