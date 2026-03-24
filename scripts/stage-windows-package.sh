#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 6 ]; then
  echo "usage: $0 <stage-dir> <readme> <clawstation-exe> <webview2-dll> <clawops-exe> <gcc-bin-or-empty>" >&2
  exit 2
fi

stage_dir="$1"
readme_path="$2"
clawstation_bin="$3"
webview2_dll="$4"
clawops_bin="$5"
gcc_bin="$6"

resolve_objdump() {
  if command -v x86_64-w64-mingw32-objdump >/dev/null 2>&1; then
    printf '%s\n' "x86_64-w64-mingw32-objdump"
    return 0
  fi
  if command -v llvm-objdump >/dev/null 2>&1; then
    printf '%s\n' "llvm-objdump"
    return 0
  fi
  if command -v objdump >/dev/null 2>&1; then
    printf '%s\n' "objdump"
    return 0
  fi
  return 1
}

copy_if_exists() {
  local source_path="$1"
  local target_path="$2"
  if [ -f "$source_path" ]; then
    cp -f "$source_path" "$target_path"
    return 0
  fi
  return 1
}

resolve_gcc_runtime_dll() {
  local dll_name="$1"
  if [ -z "$gcc_bin" ] || [ ! -x "$gcc_bin" ]; then
    return 1
  fi
  local resolved
  resolved="$("$gcc_bin" -print-file-name="$dll_name" 2>/dev/null || true)"
  if [ -n "$resolved" ] && [ "$resolved" != "$dll_name" ] && [ -f "$resolved" ]; then
    printf '%s\n' "$resolved"
    return 0
  fi
  return 1
}

objdump_bin="$(resolve_objdump || true)"

rm -rf "$stage_dir"
mkdir -p "$stage_dir"

cp -f "$clawstation_bin" "$stage_dir/clawstation.exe"
cp -f "$clawops_bin" "$stage_dir/clawops.exe"
copy_if_exists "$webview2_dll" "$stage_dir/$(basename "$webview2_dll")" || true
cp -f "$readme_path" "$stage_dir/README.txt"

declare -A system_dlls=(
  ["advapi32.dll"]=1
  ["api-ms-win-core-synch-l1-2-0.dll"]=1
  ["api-ms-win-core-winrt-error-l1-1-0.dll"]=1
  ["bcrypt.dll"]=1
  ["bcryptprimitives.dll"]=1
  ["comctl32.dll"]=1
  ["dwmapi.dll"]=1
  ["gdi32.dll"]=1
  ["imm32.dll"]=1
  ["kernel32.dll"]=1
  ["msvcrt.dll"]=1
  ["ntdll.dll"]=1
  ["ole32.dll"]=1
  ["oleaut32.dll"]=1
  ["propsys.dll"]=1
  ["shell32.dll"]=1
  ["shlwapi.dll"]=1
  ["user32.dll"]=1
  ["userenv.dll"]=1
  ["ws2_32.dll"]=1
)

if [ -n "$objdump_bin" ]; then
  for exe in "$stage_dir/clawstation.exe" "$stage_dir/clawops.exe"; do
    while IFS= read -r dll_name; do
      [ -n "$dll_name" ] || continue
      dll_lower="$(printf '%s' "$dll_name" | tr '[:upper:]' '[:lower:]')"
      if [[ "$dll_lower" == api-ms-win-* ]] || [ -n "${system_dlls[$dll_lower]:-}" ]; then
        continue
      fi
      if [ -f "$stage_dir/$dll_name" ]; then
        continue
      fi

      found=0
      for candidate in \
        "$(dirname "$clawstation_bin")/$dll_name" \
        "$(dirname "$clawops_bin")/$dll_name" \
        "$(dirname "$webview2_dll")/$dll_name"
      do
        if copy_if_exists "$candidate" "$stage_dir/$dll_name"; then
          found=1
          break
        fi
      done

      if [ "$found" -eq 0 ]; then
        gcc_candidate="$(resolve_gcc_runtime_dll "$dll_name" || true)"
        if [ -n "$gcc_candidate" ] && copy_if_exists "$gcc_candidate" "$stage_dir/$dll_name"; then
          found=1
        fi
      fi

      if [ "$found" -eq 0 ]; then
        printf 'warning: unresolved Windows runtime DLL %s (referenced by %s)\n' "$dll_name" "$(basename "$exe")" >&2
      fi
    done < <("$objdump_bin" -p "$exe" 2>/dev/null | awk -F': ' '/DLL Name/ {print $2}' | sort -u)
  done
else
  echo "warning: no objdump binary found; skipping Windows runtime DLL discovery" >&2
fi
