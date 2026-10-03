#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device_id="${1:-}"
if [ -z "$device_id" ]; then
  device_id="$(xcrun simctl list devices available --json | python3 -c 'import json,sys; ds=[d for k,v in json.load(sys.stdin)["devices"].items() if "iOS" in k for d in v if "iPhone" in d["name"]]; ds.sort(key=lambda d:d["state"]!="Booted"); print(ds[0]["udid"] if ds else "")')"
fi
if [ -z "$device_id" ]; then
  echo 'No available iPhone simulator. Install an iOS runtime in Xcode.' >&2
  exit 1
fi
result_path="build/TestResults/KaX-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project KaX.xcodeproj -scheme KaX \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath build/DerivedData -resultBundlePath "$result_path" \
  -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
