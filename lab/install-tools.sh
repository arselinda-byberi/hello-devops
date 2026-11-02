#!/usr/bin/env bash
# Runs once when the Codespace is created: installs k3d and the app's dev dependencies.
set -euo pipefail

K3D_VERSION="v5.7.4"

if ! command -v k3d >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG="${K3D_VERSION}" bash
fi

pip install --quiet --user -r app/requirements-dev.txt

echo "Tools ready. Start the lab with:  bash lab/up.sh"
