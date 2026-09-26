#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
python_bin="${PYTHON_BIN:-python3}"
ready_file="$(mktemp "${TMPDIR:-/tmp}/whytea-mock.XXXXXX")"
server_log="${WHYTEA_MOCK_LOG:-/private/tmp/whytea-mock-server.log}"
server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -f "$ready_file"
}
trap cleanup EXIT INT TERM

cd "$repo_root"
"$python_bin" Server/YouTubeMock/server.py \
  --port 0 \
  --ready-file "$ready_file" \
  >"$server_log" 2>&1 &
server_pid=$!

for _ in $(seq 1 100); do
  if [[ -s "$ready_file" ]]; then break; fi
  sleep 0.05
done
if [[ ! -s "$ready_file" ]]; then
  echo "WhyTeaMock did not become ready; see $server_log" >&2
  exit 1
fi

mock_origin="$(<"$ready_file")"
WHYTEA_MOCK_BASE_URL="$mock_origin" \
  swift test --package-path Packages/WhyTeaYouTube --filter MockYouTubeClientTests
