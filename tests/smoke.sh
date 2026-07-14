#!/usr/bin/env bash
# End-to-end smoke test: start a headless Factorio server in a container with
# the packaged mod installed, invoke /fsn-pulse over RCON, and assert the
# output line matches the documented contract.
#
# Requires: docker or podman, python3. Override the image with FACTORIO_IMAGE,
# the host RCON port with RCON_PORT, the runtime with CONTAINER_RUNTIME.
set -euo pipefail

cd "$(dirname "$0")/.."

RUNTIME="${CONTAINER_RUNTIME:-$(command -v docker || command -v podman)}"
if [ -z "$RUNTIME" ]; then
  echo "Neither docker nor podman found." >&2
  exit 1
fi

IMAGE="${FACTORIO_IMAGE:-docker.io/factoriotools/factorio:stable}"

# The arm64 variant of the image runs Factorio's x86-64 binary through box64,
# which segfaults under some hosts (observed on Apple Silicon podman VMs).
# Force the amd64 image on arm64 hosts; macOS runs it via Rosetta.
PLATFORM_ARGS=""
if [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
  PLATFORM_ARGS="--platform linux/amd64"
fi

CONTAINER="fsn-pulse-smoke"
RCON_PORT="${RCON_PORT:-27015}"
RCON_PW="fsn-pulse-smoke"
CONTRACT_RE='^FSN-PULSE v2 tick=[0-9]+ speed=[0-9.eE+-]+ paused=(true|false) players=[0-9]+$'

./scripts/package.sh
VERSION=$(python3 -c 'import json; print(json.load(open("info.json"))["version"])')
ZIP="dist/fsn-pulse_${VERSION}.zip"

STAGE=$(mktemp -d)
mkdir -p "$STAGE/config" "$STAGE/mods"
printf '%s' "$RCON_PW" > "$STAGE/config/rconpw"
cp "$ZIP" "$STAGE/mods/"

cleanup() {
  "$RUNTIME" rm -f -v "$CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$STAGE"
}
trap cleanup EXIT

# Seed the container's /factorio volume via cp instead of bind-mounting a
# host directory — bind mounts hit ownership problems under rootless podman
# and macOS VMs, and this way works identically everywhere.
"$RUNTIME" rm -f -v "$CONTAINER" >/dev/null 2>&1 || true
# shellcheck disable=SC2086 # intentional word splitting of PLATFORM_ARGS
"$RUNTIME" create --name "$CONTAINER" $PLATFORM_ARGS \
  -p "127.0.0.1:${RCON_PORT}:27015" \
  "$IMAGE" >/dev/null
"$RUNTIME" cp "$STAGE/config" "$CONTAINER:/factorio/"
"$RUNTIME" cp "$STAGE/mods" "$CONTAINER:/factorio/"
"$RUNTIME" start "$CONTAINER" >/dev/null

echo "Waiting for the server to accept RCON and answer /fsn-pulse ..."
LINE=""
for _ in $(seq 1 90); do
  if [ "$("$RUNTIME" inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
    echo "FAIL: server container exited early."
    break
  fi
  LINE=$(python3 tests/rcon_client.py 127.0.0.1 "$RCON_PORT" "$RCON_PW" "/fsn-pulse" 2>/dev/null | tr -d '\r' || true)
  if [[ "$LINE" =~ $CONTRACT_RE ]]; then
    echo "PASS: $LINE"
    exit 0
  fi
  sleep 2
done

echo "FAIL: never got a contract-conforming response."
echo "Last response: ${LINE:-<none>}"
echo "--- last server log lines ---"
"$RUNTIME" logs "$CONTAINER" 2>&1 | tail -40 || true
exit 1
