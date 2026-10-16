#!/usr/bin/env python3
"""Turn `flutter analyze` output into GitHub annotations.

Annotations show up on the pull request files and can be read through the API
without opening the job log. GitHub keeps at most 10 error and 10 warning
annotations per step, so the workflow runs this script once per slice.

Usage: annotate_analyze.py <analyze.txt> <slice-index>
"""
import re
import sys

PER_STEP = 10

path, chunk = sys.argv[1], int(sys.argv[2])
# example: "  error • Undefined name 'x' • lib/main.dart:12:5 • undefined_identifier"
pattern = re.compile(
    r'^\s*(error|warning)\s+•\s+(.*?)\s+•\s+(\S+?):(\d+):(\d+)\s+•\s+(\S+)\s*$'
)

found = {'error': [], 'warning': []}
with open(path, encoding='utf-8', errors='replace') as fh:
    for line in fh:
        m = pattern.match(line)
        if m:
            level, message, file, line_no, col, code = m.groups()
            found[level].append((message, file, line_no, col, code))

for level, rows in found.items():
    for message, file, line_no, col, code in rows[chunk * PER_STEP:(chunk + 1) * PER_STEP]:
        message = message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print(f'::{level} file={file},line={line_no},col={col},title={code}::{message}')

if chunk == 0:
    print(f"analyzer: {len(found['error'])} error(s), {len(found['warning'])} warning(s)")
