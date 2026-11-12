#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:?Usage: smoke-test.sh IMAGE}"
EXPECTED_VERSION="10.10.7"
RUN_ID="$(date +%s)-$$"
NETWORK="jellyfin-smoke-net-${RUN_ID}"
CONTAINER="jellyfin-smoke-${RUN_ID}"
LOG_DIR="${SMOKE_LOG_DIR:-smoke-results}"
mkdir -p "$LOG_DIR"

cleanup() {
    docker logs "$CONTAINER" > "$LOG_DIR/jellyfin.log" 2>&1 || true
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "=== Creating private Docker network ==="
docker network create "$NETWORK" >/dev/null

echo "=== Starting Jellyfin ==="
docker run -d \
    --name "$CONTAINER" \
    --network "$NETWORK" \
    --label "ci.owner=${RUN_ID}" \
    "$IMAGE" >/dev/null

echo "=== Waiting for Jellyfin health endpoint ==="
READY=0

for i in $(seq 1 60); do
    if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -qx true; then
        echo "ERROR: Jellyfin container stopped unexpectedly"
        exit 1
    fi

    if docker run --rm \
        --network "$NETWORK" \
        curlimages/curl:8.11.1 \
        -fsS --max-time 3 \
        "http://${CONTAINER}:8096/health" \
        > "$LOG_DIR/health.txt" 2>/dev/null; then
        READY=1
        break
    fi

    sleep 2
done

if [ "$READY" -ne 1 ]; then
    echo "ERROR: Jellyfin did not become healthy"
    exit 1
fi

echo "PASS: /health returned HTTP 200"

echo "=== Checking Jellyfin version ==="
docker run --rm \
    --network "$NETWORK" \
    curlimages/curl:8.11.1 \
    -fsS --max-time 10 \
    "http://${CONTAINER}:8096/System/Info/Public" \
    > "$LOG_DIR/system-info.json"

python3 - "$LOG_DIR/system-info.json" "$EXPECTED_VERSION" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    info = json.load(f)

actual = info.get("Version")
expected = sys.argv[2]

if actual != expected:
    raise SystemExit(f"FAIL: Expected version {expected}, got {actual}")

print(f"PASS: Jellyfin version {actual}")
PY


echo "=== Checking Web UI ==="
docker run --rm --network "$NETWORK" curlimages/curl:8.11.1 \
    -fsS --max-time 15 \
    "http://${CONTAINER}:8096/web/index.html" \
    > "$LOG_DIR/index.html"

python3 - "$LOG_DIR/index.html" <<'PYHTML'
from pathlib import Path
import sys

html = Path(sys.argv[1]).read_text(encoding="utf-8")
if "<html" not in html.lower() or "<script" not in html.lower():
    raise SystemExit("FAIL: Web UI HTML is invalid")
print("PASS: Web UI HTML")
PYHTML

echo "=== Checking Web JS/CSS assets ==="
python3 - "$LOG_DIR/index.html" "$LOG_DIR/web-assets.txt" <<'PYASSETS'
from html.parser import HTMLParser
from pathlib import Path
import sys

class Assets(HTMLParser):
    def __init__(self):
        super().__init__()
        self.js = []
        self.css = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "script" and a.get("src"):
            self.js.append(a["src"])
        if tag == "link" and a.get("rel", "").lower() == "stylesheet" and a.get("href"):
            self.css.append(a["href"])

html = Path(sys.argv[1]).read_text(encoding="utf-8")
parser = Assets()
parser.feed(html)

if not parser.js:
    raise SystemExit("FAIL: Missing JavaScript references")

assets = [
    ("JS", parser.js[0]),
    ("CSS", "themes/dark/theme.css")
]
Path(sys.argv[2]).write_text(
    "\n".join(f"{kind} {url}" for kind, url in assets) + "\n",
    encoding="utf-8"
)
print("PASS: Found JS and CSS references")
PYASSETS

while read -r KIND ASSET; do
    ASSET="${ASSET%%\?*}"
    case "$ASSET" in
        http://*|https://*|//*)
            echo "FAIL: External asset reference: $ASSET"
            exit 1
            ;;
        /web/*) URL="http://${CONTAINER}:8096${ASSET}" ;;
        /*) URL="http://${CONTAINER}:8096${ASSET}" ;;
        *) URL="http://${CONTAINER}:8096/web/${ASSET#./}" ;;
    esac

    docker run --rm --network "$NETWORK" curlimages/curl:8.11.1 \
        -fsS --max-time 15 -o /dev/null "$URL"

    echo "PASS: $KIND asset available"
done < "$LOG_DIR/web-assets.txt"

echo "=== Checking FFmpeg ==="
docker run --rm --entrypoint ffmpeg "$IMAGE" -version \
    > "$LOG_DIR/ffmpeg.txt"
grep -q "ffmpeg version" "$LOG_DIR/ffmpeg.txt"
echo "PASS: FFmpeg"

echo "=== Checking non-root user ==="
UID_VALUE="$(docker exec "$CONTAINER" id -u)"
if [ "$UID_VALUE" = "0" ]; then
    echo "FAIL: Jellyfin is running as root"
    exit 1
fi
echo "PASS: Non-root UID $UID_VALUE"

echo "=== Checking writable directories ==="
docker exec "$CONTAINER" /bin/sh -ec '
    for dir in /config /cache; do
        test -w "$dir"
    done
'
echo "PASS: Writable directories"

echo "=== Smoke Test PASSED ==="
