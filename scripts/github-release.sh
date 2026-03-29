#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REMOTE="origin"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
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

Default flow:
  Push the release commit and tag only. GitHub Actions builds and publishes the
  official Windows asset after the tag is pushed. Local compilation is not part
  of the release process.
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

build_notes_file() {
  local notes_path="$1"
  local tag="$2"
  local title="$3"
  local _version="$4"
  local base_ref="$5"

  mkdir -p "$(dirname "$notes_path")"

  bash "$ROOT_DIR/scripts/generate-release-notes.sh" \
    "$tag" \
    "$title" \
    "$notes_path" \
    "$base_ref"
}

require_cmd git
HAS_GH=1
if ! command -v gh >/dev/null 2>&1; then
  HAS_GH=0
  if [[ "$SKIP_RELEASE" -eq 0 ]]; then
    echo "warning: gh not found locally; release metadata creation will be delegated to GitHub Actions after the tag push." >&2
    SKIP_RELEASE=1
  fi
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

build_notes_file "$NOTES_FILE" "$TAG" "$TITLE" "$version" "$BASE_REF"

run_cmd git fetch --tags "$REMOTE"
run_cmd git tag -a "$TAG" -F "$NOTES_FILE"

if [[ "$SKIP_BRANCH_PUSH" -eq 0 ]]; then
  run_cmd git push "$REMOTE" "$BRANCH"
fi
run_cmd git push "$REMOTE" "refs/tags/${TAG}"

if [[ "$SKIP_RELEASE" -eq 0 ]]; then
  if gh release view "$TAG" >/dev/null 2>&1; then
    run_cmd gh release edit "$TAG" --title "$TITLE" --notes-file "$NOTES_FILE"
  else
    create_args=(release create "$TAG")
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
Release asset: generated later by GitHub Actions
Local gh available: $([[ "$HAS_GH" -eq 1 ]] && printf 'true' || printf 'false')
GitHub Release metadata via local gh: $([[ "$SKIP_RELEASE" -eq 0 ]] && printf 'true' || printf 'false')
Remote:     ${REMOTE}
Branch:     ${BRANCH}
EOF
