#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_DIR="$(mktemp -d)"
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc -module-cache-path "$CHECK_DIR/module-cache" PlantaoNaMao/Models.swift PlantaoNaMao/FinanceModels.swift PlantaoNaMao/SyncModels.swift PlantaoNaMao/WidgetData.swift Tests/ModelChecks.swift -o "$CHECK_DIR/model-checks"
TZ=America/Sao_Paulo "$CHECK_DIR/model-checks"
TZ=America/New_York "$CHECK_DIR/model-checks"
