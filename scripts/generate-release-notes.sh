#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: scripts/generate-release-notes.sh <tag> <title> <output-file> [base-ref] [asset-path]" >&2
  exit 2
fi

TAG="$1"
TITLE="$2"
OUTPUT_FILE="$3"
BASE_REF="${4:-}"
ASSET_PATH="${5:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

range_spec() {
  if [[ -n "$BASE_REF" ]]; then
    printf '%s..%s' "$BASE_REF" "$TAG"
  else
    printf '%s' "$TAG"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

classify_subject() {
  local lower="$1"

  if [[ "$lower" =~ ^(ci|chore|docs|doc|build|release)(\(.+\))?:[[:space:]] ]]; then
    return 1
  fi
  if [[ "$lower" =~ ^(prepare|archive|track|clarify|rename|refresh)[[:space:]] ]]; then
    return 1
  fi

  if [[ "$lower" =~ (^feat(\(.+\))?:)|(^add[[:space:]])|(^support[[:space:]])|(^introduce[[:space:]])|(^enable[[:space:]]) ]]; then
    printf 'feature'
    return 0
  fi

  if [[ "$lower" =~ (^fix(\(.+\))?:)|(^bugfix[[:space:]])|(^avoid[[:space:]])|(^resolve[[:space:]])|(^repair[[:space:]])|(^correct[[:space:]]) ]]; then
    printf 'fix'
    return 0
  fi

  if [[ "$lower" =~ (wizard|dialog|chat|gateway|pairing|token|instance|deploy|probe|restart|rollback|auth|credential|diagnostic|log|tunnel|browser|storage|security|encrypt|private[[:space:]]key|password) ]]; then
    printf 'improvement'
    return 0
  fi

  return 1
}

append_entry() {
  local file="$1"
  local text="$2"
  if [[ -n "$text" ]]; then
    printf -- '- %s\n' "$text" >> "$file"
  fi
}

mkdir -p "$(dirname "$OUTPUT_FILE")"

tmp_feature="$(mktemp)"
tmp_fix="$(mktemp)"
tmp_improvement="$(mktemp)"
trap 'rm -f "$tmp_feature" "$tmp_fix" "$tmp_improvement"' EXIT

while IFS=$'\t' read -r sha subject; do
  subject="$(trim "$subject")"
  [[ -z "$subject" ]] && continue

  lower="$(printf '%s' "$subject" | tr '[:upper:]' '[:lower:]')"
  if ! bucket="$(classify_subject "$lower")"; then
    continue
  fi

  case "$bucket" in
    feature)
      append_entry "$tmp_feature" "$subject"
      ;;
    fix)
      append_entry "$tmp_fix" "$subject"
      ;;
    improvement)
      append_entry "$tmp_improvement" "$subject"
      ;;
  esac
done < <(git log --no-merges --format='%h%x09%s' "$(range_spec)")

asset_size="-"
asset_sha="-"
asset_name=""
if [[ -n "$ASSET_PATH" && -f "$ASSET_PATH" ]]; then
  asset_name="$(basename "$ASSET_PATH")"
  asset_size="$(wc -c < "$ASSET_PATH" | tr -d '[:space:]')"
  asset_sha="$(sha256sum "$ASSET_PATH" | awk '{print $1}')"
fi

{
  printf '# %s\n\n' "$TITLE"

  if [[ -s "$tmp_feature" ]]; then
    printf '## 新增特性\n\n'
    cat "$tmp_feature"
    printf '\n'
  fi

  if [[ -s "$tmp_fix" ]]; then
    printf '## 问题修复\n\n'
    cat "$tmp_fix"
    printf '\n'
  fi

  if [[ -s "$tmp_improvement" ]]; then
    printf '## 其他改进\n\n'
    cat "$tmp_improvement"
    printf '\n'
  fi

  if [[ ! -s "$tmp_feature" && ! -s "$tmp_fix" && ! -s "$tmp_improvement" ]]; then
    printf '## 更新内容\n\n'
    printf -- '- 本次发布未记录到明确的用户可见功能变更。\n\n'
  fi

  if [[ -n "$asset_name" ]]; then
    printf '## 发布包\n\n'
    printf -- '- 文件：`%s`\n' "$asset_name"
    printf -- '- SHA256：`%s`\n' "$asset_sha"
    printf -- '- 大小(bytes)：`%s`\n' "$asset_size"
  fi
} > "$OUTPUT_FILE"
