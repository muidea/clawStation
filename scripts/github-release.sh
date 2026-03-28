#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REMOTE="origin"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
ASSET_PATH="$ROOT_DIR/output/ClawStation-windows-x86_64-gnu.zip"
NOTES_FILE=""
TITLE=""
TAG=""
BASE_REF=""
DRAFT=0
DRY_RUN=0
SKIP_BRANCH_PUSH=0
SKIP_RELEASE=0
ALLOW_DIRTY=0

usage() {
  cat <<'EOF'
Usage: scripts/github-release.sh [options]

Options:
  --tag <tag>              Use an explicit tag instead of auto-generating one.
  --title <title>          GitHub Release title. Defaults to the final tag.
  --asset <path>           Release asset to upload. Defaults to output/ClawStation-windows-x86_64-gnu.zip.
  --notes-file <path>      Write the generated summary to an explicit file.
  --base-ref <ref>         Use a custom git ref as the summary start point.
  --remote <name>          Git remote to push to. Defaults to origin.
  --branch <name>          Branch to push. Defaults to the current branch.
  --draft                  Create the GitHub Release as draft.
  --skip-branch-push       Only push the tag, skip pushing the current branch.
  --skip-release           Do not call gh release create/upload; only create notes and push git refs.
  --allow-dirty            Allow running with uncommitted changes.
  --dry-run                Print planned commands without executing them.
  -h, --help               Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --asset)
      ASSET_PATH="${2:-}"
      shift 2
      ;;
    --notes-file)
      NOTES_FILE="${2:-}"
      shift 2
      ;;
    --base-ref)
      BASE_REF="${2:-}"
      shift 2
      ;;
    --remote)
      REMOTE="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
      shift 2
      ;;
    --draft)
      DRAFT=1
      shift
      ;;
    --skip-branch-push)
      SKIP_BRANCH_PUSH=1
      shift
      ;;
    --skip-release)
      SKIP_RELEASE=1
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] %q' "$1"
    shift
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
    return 0
  fi

  "$@"
}

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "required command not found: $name" >&2
    exit 2
  fi
}

detect_version() {
  if command -v node >/dev/null 2>&1; then
    node -p "require('./clawconsole/package.json').version"
    return 0
  fi

  sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*$/\1/p' clawconsole/package.json | head -n 1
}

assert_clean_worktree() {
  if [[ "$ALLOW_DIRTY" -eq 1 ]]; then
    return 0
  fi

  local status
  status="$(git status --short --untracked-files=normal)"
  if [[ -n "$status" ]]; then
    echo "refusing to release from a dirty worktree; commit or stash changes first." >&2
    echo "$status" >&2
    exit 2
  fi
}

git_ref_exists() {
  git rev-parse --verify --quiet "$1" >/dev/null 2>&1
}

render_commit_lines() {
  local range="$1"
  local lines
  if [[ -n "$range" ]]; then
    lines="$(git log --no-merges --pretty=format:'- %s (%h)' "$range" --max-count=30)"
  else
    lines="$(git log --no-merges --pretty=format:'- %s (%h)' --max-count=30)"
  fi

  if [[ -n "$lines" ]]; then
    printf '%s\n' "$lines"
  else
    printf '%s\n' "- No non-merge commits found."
  fi
}

render_changed_areas() {
  local range="$1"
  local files
  if [[ -n "$range" ]]; then
    files="$(git diff --name-only "$range")"
  else
    files="$(git show --pretty='' --name-only HEAD)"
  fi

  if [[ -z "$files" ]]; then
    printf '%s\n' "- No file changes detected."
    return 0
  fi

  printf '%s\n' "$files" | awk '
    BEGIN {
      counts["clawconsole"] = 0;
      counts["clawops"] = 0;
      counts["docs"] = 0;
      counts["github"] = 0;
      counts["scripts"] = 0;
      counts["other"] = 0;
    }
    /^clawconsole\// { counts["clawconsole"]++; next }
    /^clawops\// { counts["clawops"]++; next }
    /^docs\// { counts["docs"]++; next }
    /^\.github\// { counts["github"]++; next }
    /^scripts\// { counts["scripts"]++; next }
    { counts["other"]++ }
    END {
      if (counts["clawconsole"] > 0) printf("- clawconsole: %d files\n", counts["clawconsole"]);
      if (counts["clawops"] > 0) printf("- clawops: %d files\n", counts["clawops"]);
      if (counts["docs"] > 0) printf("- docs: %d files\n", counts["docs"]);
      if (counts["github"] > 0) printf("- .github: %d files\n", counts["github"]);
      if (counts["scripts"] > 0) printf("- scripts: %d files\n", counts["scripts"]);
      if (counts["other"] > 0) printf("- other: %d files\n", counts["other"]);
    }
  '
}

build_notes_file() {
  local notes_path="$1"
  local tag="$2"
  local title="$3"
  local version="$4"
  local base_ref="$5"
  local compare_range="$6"
  local asset_path="$7"
  local head_sha branch_name asset_sha asset_size

  head_sha="$(git rev-parse --short HEAD)"
  branch_name="$BRANCH"
  asset_sha="-"
  asset_size="-"

  mkdir -p "$(dirname "$notes_path")"

  if [[ -f "$asset_path" ]]; then
    asset_sha="$(sha256sum "$asset_path" | awk '{print $1}')"
    asset_size="$(wc -c < "$asset_path" | tr -d '[:space:]')"
  fi

  cat > "$notes_path" <<EOF
# ${title}

## 发布信息

- Tag: \`${tag}\`
- Version: \`${version}\`
- Date: \`$(date '+%Y-%m-%d %H:%M:%S %Z')\`
- Branch: \`${branch_name}\`
- Commit: \`${head_sha}\`
- Remote: \`${REMOTE}\`
- Base ref: \`${base_ref:-<none>}\`

## 变更摘要

$(render_commit_lines "$compare_range")

## 变更范围

$(render_changed_areas "$compare_range")

## 发布产物

- Asset: \`$(basename "$asset_path")\`
- Path: \`${asset_path}\`
- Size(bytes): \`${asset_size}\`
- SHA256: \`${asset_sha}\`
EOF
}

require_cmd git

if [[ "$SKIP_RELEASE" -eq 0 ]]; then
  require_cmd gh
fi

version="$(detect_version)"
if [[ -z "$version" ]]; then
  echo "failed to detect version from clawconsole/package.json" >&2
  exit 2
fi

if [[ "$BRANCH" == "HEAD" ]]; then
  echo "detached HEAD is not supported; pass --branch explicitly after checking out a branch." >&2
  exit 2
fi

assert_clean_worktree

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "git remote not found: $REMOTE" >&2
  exit 2
fi

if [[ -z "$BASE_REF" ]]; then
  BASE_REF="$(git describe --tags --abbrev=0 --match 'v*' HEAD^ 2>/dev/null || true)"
fi

if [[ -z "$TAG" ]]; then
  base_tag="v${version}"
  if git_ref_exists "refs/tags/${base_tag}"; then
    TAG="${base_tag}-$(date '+%Y%m%d%H%M%S')"
  else
    TAG="${base_tag}"
  fi
fi

if [[ -z "$TITLE" ]]; then
  TITLE="$TAG"
fi

if [[ -z "$NOTES_FILE" ]]; then
  NOTES_FILE="$ROOT_DIR/output/release-notes-${TAG}.md"
fi

if git_ref_exists "refs/tags/${TAG}"; then
  echo "git tag already exists locally: ${TAG}" >&2
  exit 2
fi

if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "git tag already exists on remote ${REMOTE}: ${TAG}" >&2
  exit 2
fi

compare_range=""
if [[ -n "$BASE_REF" ]]; then
  compare_range="${BASE_REF}..HEAD"
fi

if [[ ! -f "$ASSET_PATH" ]]; then
  echo "warning: release asset not found, release will be created without upload: ${ASSET_PATH}" >&2
fi

build_notes_file "$NOTES_FILE" "$TAG" "$TITLE" "$version" "$BASE_REF" "$compare_range" "$ASSET_PATH"

run_cmd git fetch --tags "$REMOTE"
run_cmd git tag -a "$TAG" -F "$NOTES_FILE"

if [[ "$SKIP_BRANCH_PUSH" -eq 0 ]]; then
  run_cmd git push "$REMOTE" "$BRANCH"
fi
run_cmd git push "$REMOTE" "refs/tags/${TAG}"

if [[ "$SKIP_RELEASE" -eq 0 ]]; then
  if gh release view "$TAG" >/dev/null 2>&1; then
    run_cmd gh release edit "$TAG" --title "$TITLE" --notes-file "$NOTES_FILE"
    if [[ -f "$ASSET_PATH" ]]; then
      run_cmd gh release upload "$TAG" "$ASSET_PATH" --clobber
    fi
  else
    create_args=(release create "$TAG")
    if [[ -f "$ASSET_PATH" ]]; then
      create_args+=("$ASSET_PATH")
    fi
    create_args+=(--title "$TITLE" --notes-file "$NOTES_FILE")
    if [[ "$DRAFT" -eq 1 ]]; then
      create_args+=(--draft)
    fi
    run_cmd gh "${create_args[@]}"
  fi
fi

cat <<EOF
Release preparation completed.

Tag:        ${TAG}
Title:      ${TITLE}
Notes file: ${NOTES_FILE}
Asset:      ${ASSET_PATH}
Remote:     ${REMOTE}
Branch:     ${BRANCH}
EOF
