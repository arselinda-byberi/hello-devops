#!/usr/bin/env bash
# Deletes the lab completely (Jenkins, its data, cluster, registry).
# You do NOT need this to save free hours: just stop the Codespace instead.
set -euo pipefail
docker rm -f lab-jenkins 2>/dev/null || true
docker volume rm jenkins_home 2>/dev/null || true
k3d cluster delete lab || true
k3d registry delete k3d-lab-registry.localhost || true
rm -f "$(dirname "$0")/.kubeconfig-jenkins"
echo "Lab removed."
