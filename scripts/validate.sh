#!/bin/bash
set -euo pipefail

function usage() {
  cat >&2 <<'USAGE'
Usage: validate.sh <path-to-arazzo-yaml>

Checks YAML syntax (if PyYAML is installed) and runs `openapi arazzo validate` when available.
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

TARGET="$1"
if [[ ! -f "$TARGET" ]]; then
  echo "error: file '$TARGET' does not exist" >&2
  exit 1
fi

ABS_PATH="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"
echo "Validating: $ABS_PATH" >&2

echo "Step 1/2: YAML syntax check" >&2
PY_STATUS=0
if command -v python >/dev/null 2>&1; then
  python - "$ABS_PATH" <<'PY' || PY_STATUS=$?
import sys
from pathlib import Path
path = Path(sys.argv[1])
try:
    import yaml  # type: ignore
except ModuleNotFoundError:
    print("warning: PyYAML not installed; skipping syntax check", file=sys.stderr)
    sys.exit(0)
try:
    with path.open('r', encoding='utf-8') as fh:
        yaml.safe_load(fh)
    print("YAML syntax OK", file=sys.stderr)
except Exception as exc:  # noqa: BLE001
    print(f"YAML syntax error: {exc}", file=sys.stderr)
    sys.exit(1)
PY
else
  echo "warning: python not available; skipping YAML check" >&2
fi

if [[ $PY_STATUS -ne 0 ]]; then
  exit $PY_STATUS
fi

echo "Step 2/2: Arazzo validation" >&2
if command -v openapi >/dev/null 2>&1; then
  openapi arazzo validate "$ABS_PATH"
else
  cat >&2 <<'NOCLI'
warning: Speakeasy `openapi` CLI not found on PATH.
• Install via Homebrew:   brew install openapi
• Or Go:                  go install github.com/speakeasy-api/openapi/cmd/openapi@latest
• Or script:              curl -fsSL https://go.speakeasy.com/openapi.sh | bash

Once installed, rerun this script. Alternatively, follow the manual schema instructions in references/validation-guide.md.
NOCLI
  exit 2
fi
