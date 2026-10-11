#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <converter-path>" >&2
  exit 2
fi

converter=$1
repo_root=$(cd "$(dirname "$0")/.." && pwd)
input="$repo_root/toGainMapHDR/sample/DJI_1_0927_D.heic"
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gainmap-tests.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

if [[ ! -x "$converter" ]]; then
  echo "Converter is missing or not executable: $converter" >&2
  exit 1
fi

if [[ ! -f "$input" ]]; then
  echo "Test image is missing: $input" >&2
  exit 1
fi

mkdir -p "$repo_root/build/swift-module-cache"
swiftc -module-cache-path "$repo_root/build/swift-module-cache" \
  "$repo_root/tests/verify-iso-gainmap.swift" \
  -o "$tmp_dir/verify-iso-gainmap"

assert_image() {
  local path=$1 expected_format=$2 actual_format
  [[ -s "$path" ]] || { echo "Expected non-empty output: $path" >&2; exit 1; }
  actual_format=$(sips -g format "$path" | awk '/format:/ { print $2 }')
  [[ "$actual_format" == "$expected_format" ]] || {
    echo "Expected $expected_format output at $path, got $actual_format" >&2
    exit 1
  }
}

run_success() {
  local name=$1 expected_format=$2 filename=$3
  shift 3
  local output_dir="$tmp_dir/$name"
  mkdir -p "$output_dir"
  "$converter" "$input" "$output_dir" "$@"
  assert_image "$output_dir/$filename" "$expected_format"
  if [[ "$name" == iso-* ]]; then
    "$tmp_dir/verify-iso-gainmap" "$output_dir/$filename"
  fi
  echo "PASS: $name"
}

run_failure() {
  local name=$1 expected_message=$2 filename=$3
  shift 3
  local output_dir="$tmp_dir/$name"
  mkdir -p "$output_dir"
  local output status=0
  output=$("$converter" "$input" "$output_dir" "$@" 2>&1) || status=$?
  if [[ $status -eq 0 ]]; then
    echo "Expected command to fail: $name" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected_message"* ]]; then
    echo "Expected error '$expected_message' for $name; got: $output" >&2
    exit 1
  fi
  if [[ -e "$output_dir/$filename" ]]; then
    echo "Failed command left an output file: $output_dir/$filename" >&2
    exit 1
  fi
  echo "PASS: $name rejects invalid input"
}

run_success "sdr-jpeg" jpeg "DJI_1_0927_D.jpg" -s -j
run_success "iso-heic" heic "DJI_1_0927_D.heic"
run_success "iso-subsampled-mono-jpeg" jpeg "DJI_1_0927_D.jpg" -H -m -j
run_success "suffixed-jpeg" jpeg "DJI_1_0927_D_review.jpg" -s -j -t _review

run_failure "pq-jpeg" "JPEG output does not support PQ or HLG" "DJI_1_0927_D.jpg" -p -j
run_failure "unsafe-suffix" "suffix cannot contain path separators" "DJI_1_0927_D.jpg" -s -j -t ../bad
run_failure "unknown-option" "Unknown option: --bad" "DJI_1_0927_D.heic" --bad
