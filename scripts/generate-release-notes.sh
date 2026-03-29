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
  local target_ref
  target_ref="$(resolved_target_ref)"
  if [[ -n "$BASE_REF" ]]; then
    printf '%s..%s' "$BASE_REF" "$target_ref"
  else
    printf '%s' "$target_ref"
  fi
}

resolved_target_ref() {
  if git rev-parse --verify --quiet "$TAG" >/dev/null 2>&1; then
    printf '%s' "$TAG"
  else
    printf 'HEAD'
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_subject() {
  local subject="$1"

  if [[ "$subject" =~ ^Release[[:space:]]v[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+(.+)$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  printf '%s' "$subject"
}

classify_subject() {
  local lower="$1"

  if [[ "$lower" =~ ^(ci|chore|docs|doc|build)(\(.+\))?:[[:space:]] ]]; then
    return 1
  fi
  if [[ "$lower" =~ ^(prepare|archive|track|clarify|rename|refresh)[[:space:]] ]]; then
    return 1
  fi

  if [[ "$lower" =~ (^feat(\(.+\))?:)|(^add[[:space:]])|(^support[[:space:]])|(^introduce[[:space:]])|(^enable[[:space:]]) ]]; then
    printf 'feature'
    return 0
  fi

  if [[ "$lower" =~ (^fix(\(.+\))?:)|(^bugfix[[:space:]])|(^avoid[[:space:]])|(^resolve[[:space:]])|(^repair[[:space:]])|(^correct[[:space:]])|(^.*[[:space:]]fix(es)?$)|(^.*[[:space:]]bugfix(es)?$) ]]; then
    printf 'fix'
    return 0
  fi

  if [[ "$lower" =~ (wizard|dialog|chat|gateway|pairing|token|instance|deploy|probe|restart|rollback|auth|credential|diagnostic|log|tunnel|browser|storage|security|encrypt|private[[:space:]]key|password|macos|windows|transport|integration|host[[:space:]]process|shell|path|managed[[:space:]]access) ]]; then
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

submodule_commit_at_ref() {
  local ref="$1"
  local path="$2"
  git ls-tree "$ref" "$path" 2>/dev/null | awk 'NR == 1 { print $3 }'
}

append_release_entry() {
  local subject="$1"
  local prefix="${2:-}"
  local normalized
  local text
  local lower
  local bucket

  normalized="$(normalize_subject "$subject")"
  text="$normalized"
  if [[ -n "$prefix" ]]; then
    text="${prefix}${normalized}"
  fi

  lower="$(printf '%s' "$normalized" | tr '[:upper:]' '[:lower:]')"
  if ! bucket="$(classify_subject "$lower")"; then
    return 0
  fi

  case "$bucket" in
    feature)
      append_entry "$tmp_feature" "$text"
      ;;
    fix)
      append_entry "$tmp_fix" "$text"
      ;;
    improvement)
      append_entry "$tmp_improvement" "$text"
      ;;
  esac
}

collect_component_notes() {
  local component_path="$1"
  local component_label="$2"
  local base_sha="$3"
  local target_sha="$4"
  local line
  local sha
  local subject

  if [[ -z "$base_sha" || -z "$target_sha" || "$base_sha" == "$target_sha" ]]; then
    return 0
  fi

  if ! git -C "$component_path" rev-parse --verify --quiet "${base_sha}^{commit}" >/dev/null 2>&1; then
    return 0
  fi

  if ! git -C "$component_path" rev-parse --verify --quiet "${target_sha}^{commit}" >/dev/null 2>&1; then
    return 0
  fi

  while IFS=$'\t' read -r sha subject; do
    subject="$(trim "$subject")"
    [[ -z "$subject" ]] && continue
    append_release_entry "$subject" "${component_label}："
  done < <(git -C "$component_path" log --no-merges --format='%h%x09%s' "${base_sha}..${target_sha}")
}

mkdir -p "$(dirname "$OUTPUT_FILE")"

tmp_feature="$(mktemp)"
tmp_fix="$(mktemp)"
tmp_improvement="$(mktemp)"
trap 'rm -f "$tmp_feature" "$tmp_fix" "$tmp_improvement"' EXIT

while IFS=$'\t' read -r sha subject; do
  subject="$(trim "$subject")"
  [[ -z "$subject" ]] && continue
  append_release_entry "$subject"
done < <(git log --no-merges --format='%h%x09%s' "$(range_spec)")

target_tree_ref="$(resolved_target_ref)"
if [[ -n "$BASE_REF" ]] && git rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
  base_clawconsole_sha="$(submodule_commit_at_ref "$BASE_REF" "clawconsole")"
  target_clawconsole_sha="$(submodule_commit_at_ref "$target_tree_ref" "clawconsole")"
  collect_component_notes "clawconsole" "clawconsole" "$base_clawconsole_sha" "$target_clawconsole_sha"

  base_clawops_sha="$(submodule_commit_at_ref "$BASE_REF" "clawops")"
  target_clawops_sha="$(submodule_commit_at_ref "$target_tree_ref" "clawops")"
  collect_component_notes "clawops" "clawops" "$base_clawops_sha" "$target_clawops_sha"
fi

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
