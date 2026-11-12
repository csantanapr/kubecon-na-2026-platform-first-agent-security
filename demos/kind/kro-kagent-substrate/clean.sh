#!/usr/bin/env bash
# Delete the kind cluster and everything in it. Downloaded CLIs in .work/bin stay.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
kind delete cluster --name kro-agents --kubeconfig "$HERE/.work/kubeconfig"
rm -f "$HERE/.work/kubeconfig" "$HERE/.work/port-forward.log"
