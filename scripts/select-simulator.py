#!/usr/bin/env python3
import json
import re
import sys

devices = json.load(sys.stdin)["devices"]
runtimes = sorted(
    (key for key in devices if "iOS-26" in key),
    key=lambda key: tuple(map(int, re.findall(r"\d+", key.rsplit("iOS-", 1)[1]))),
    reverse=True,
)
for runtime in runtimes:
    candidates = [device for device in devices[runtime] if "iPhone" in device["name"]]
    if candidates:
        preferred = next((device for device in candidates if device["name"] == "iPhone 17 Pro"), candidates[0])
        print(preferred["udid"])
        sys.exit(0)
raise SystemExit("Nenhum simulador iPhone iOS 26 disponível")
