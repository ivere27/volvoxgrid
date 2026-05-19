#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 Package.swift target-name url checksum" >&2
  exit 2
fi

package_file="$1"
target_name="$2"
target_url="$3"
target_checksum="$4"

if [ ! -f "$package_file" ]; then
  echo "error: Package.swift not found: $package_file" >&2
  exit 1
fi

if [ -z "$target_url" ]; then
  echo "error: target URL is empty for $target_name" >&2
  exit 1
fi

if [ -z "$target_checksum" ]; then
  echo "error: checksum is empty for $target_name" >&2
  exit 1
fi

tmp_file="$(mktemp "${package_file}.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

TARGET_NAME="$target_name" \
TARGET_URL="$target_url" \
TARGET_CHECKSUM="$target_checksum" \
perl -0pe '
  my $target = quotemeta($ENV{"TARGET_NAME"});
  my $url = $ENV{"TARGET_URL"};
  my $checksum = $ENV{"TARGET_CHECKSUM"};
  my $count = s/(\.binaryTarget\(\s*name:\s*"$target",\s*url:\s*")[^"]+(",\s*checksum:\s*")[^"]+(")/$1 . $url . $2 . $checksum . $3/sge;
  die "error: binaryTarget not found: $ENV{TARGET_NAME}\n" unless $count == 1;
' "$package_file" > "$tmp_file"

mv "$tmp_file" "$package_file"
trap - EXIT
