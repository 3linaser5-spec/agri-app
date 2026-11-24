#!/usr/bin/env python3
"""يفشل البناء إذا نزلت تغطية الأسطر عن الحد الأدنى.

الاستخدام:
    python3 scripts/check_coverage.py coverage/lcov.info 73
"""

import sys
from pathlib import Path

DEFAULT_THRESHOLD = 73.0


def main() -> int:
    lcov = Path(sys.argv[1] if len(sys.argv) > 1 else "coverage/lcov.info")
    minimum = float(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_THRESHOLD

    if not lcov.is_file():
        print(f"ملف التغطية غير موجود: {lcov}", file=sys.stderr)
        return 1

    total = hit = 0
    for line in lcov.read_text(encoding="utf-8").splitlines():
        if line.startswith("DA:"):
            parts = line[3:].split(",")
            if len(parts) < 2:
                continue
            total += 1
            if int(parts[1]) > 0:
                hit += 1

    if total == 0:
        print("لا توجد أسطر قابلة للقياس في ملف التغطية.", file=sys.stderr)
        return 1

    percent = 100 * hit / total
    print(
        f"تغطية الأسطر: {percent:.2f}% ({hit}/{total}) — "
        f"الحد الأدنى المطلوب {minimum:.1f}%"
    )
    if percent < minimum:
        print("التغطية أقل من الحد الأدنى.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
