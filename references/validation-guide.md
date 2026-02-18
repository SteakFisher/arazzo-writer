# Validation & Tooling Guide

Use this guide to ensure every `.arazzo.yaml` file is syntactically correct, schema-compliant, and ready for automation. Prioritize automated validation whenever tooling exists in the workspace.

## 1. YAML Syntax Validation
1. **PyYAML (preferred):**
   ```bash
   python - <<'PY'
   import yaml, sys
   yaml.safe_load(open('workflow.arazzo.yaml'))
   PY
   ```
   - If `ModuleNotFoundError: yaml`, install with `pip install pyyaml` or skip (schema validation may still catch errors).
2. **Node/YAML:** `npx yaml-lint workflow.arazzo.yaml` (requires `yaml-lint`).
3. **Editor tooling:** VS Code YAML plugin or IDE validators are acceptable but still run schema validation afterward.

## 2. Speakeasy OpenAPI CLI (Preferred)
The `openapi` CLI validates Arazzo workflows using the same engine as the Speakeasy Go SDK.

### Install Options
- **Homebrew (macOS/Linux):** `brew install openapi`
- **Go install:** `go install github.com/speakeasy-api/openapi/cmd/openapi@latest`
- **Shell script:** `curl -fsSL https://go.speakeasy.com/openapi.sh | bash`
- **PowerShell:** `iwr -useb https://go.speakeasy.com/openapi.ps1 | iex`

### Command
```bash
openapi arazzo validate path/to/workflow.arazzo.yaml
```
- Accepts file paths or STDIN (use `-`).
- Exit code `0` on success. Non-zero indicates validation errors (details on stderr).

### Frequent Errors
| Message | Meaning |
| --- | --- |
| `missing required property: info` | Root object missing fields |
| `step must define exactly one of operationId, operationPath, workflowId` | Step misconfiguration |
| `parameter missing 'in'` | Parameters for OpenAPI operations need `path/query/header/cookie` |
| `reference could not be resolved` | `operationId` or `workflowId` doesn’t exist |

## 3. Official Spec Validator (Node.js)
Located in `context/Arazzo-Specification/scripts/validate.mjs`.

### Usage
```bash
cd context/Arazzo-Specification
npm ci
node scripts/validate.mjs path/to/workflow.arazzo.yaml
```
Options:
- `--schema=schema` (default) or `schema-base`
- `--format=FLAG|BASIC|DETAILED|VERBOSE`

Backed by `@hyperjump/json-schema` using the official 2024-08-01 schema.

## 4. Provided Helper Script
`/mnt/skills/user/arazzo-writer/scripts/validate.sh` orchestrates:
1. File existence check
2. Optional PyYAML syntax validation
3. `openapi arazzo validate` when CLI is available
4. Installation guidance otherwise

Run it after edits:
```bash
bash /mnt/skills/user/arazzo-writer/scripts/validate.sh workflow.arazzo.yaml
```
Exit codes:
- `0`: All checks passed
- `1`: Usage/file/YAML error
- `2`: `openapi` CLI missing

## 5. Manual Checklist (No Tooling Available)
- `arazzo` string matches `1.0.x`
- `info.title` + `info.version` present
- `sourceDescriptions` has ≥1 entry with unique `name`
- Every workflow has `workflowId` + steps array (≥1)
- Each step defines exactly one of `operationId`, `operationPath`, `workflowId`
- Parameters calling OpenAPI operations include `in`
- Output keys match `^[a-zA-Z0-9._-]+$`
- `successCriteria` arrays exist where assertions are required
- Runtime expressions reference valid steps/inputs/components

## 6. CI/CD Integration Tips
- Add `openapi arazzo validate` to pipeline scripts (fails the build on errors).
- Cache the `openapi` binary or Node_modules for faster runs.
- Combine with OpenAPI spec validation so both documents stay in sync.

## 7. Troubleshooting
| Problem | Fix |
| --- | --- |
| `yaml.scanner.ScannerError` | Replace tabs with spaces; ensure indentation is consistent |
| `openapi: command not found` | Install CLI (see options above) or run Node validator |
| CLI fails due to missing HTTPS access | Download CLI manually and add to PATH, or use offline validator script |
| Validation succeeds but runtime fails | Strengthen `successCriteria` to check response shape/content |
| Large workflows unwieldy | Use `components` and multiple files to keep sections manageable |

Always re-run validation after any structural change (new steps, parameters, success criteria). Early enforcement prevents cascading fixes later.
