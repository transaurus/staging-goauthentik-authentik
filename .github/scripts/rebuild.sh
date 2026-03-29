#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for goauthentik/authentik
# Runs from {docusaurusRoot} = website/ of the existing source tree (no clone).
# Installs deps (root + workspace), then builds.

# --- Node 24 setup ---
NODE24="/opt/hostedtoolcache/node/24.14.0/x64/bin"
if [ -d "$NODE24" ]; then
    export PATH="$NODE24:$PATH"
else
    for candidate in /usr/local/bin /usr/bin; do
        if [ -f "$candidate/node" ] && "$candidate/node" -e 'process.exit(parseInt(process.versions.node) >= 24 ? 0 : 1)' 2>/dev/null; then
            export PATH="$candidate:$PATH"
            break
        fi
    done
fi

node --version
npm --version

# --- Install repo root dependencies ---
# website/package.json preinstall runs: npm ci --prefix ..
# Must install root node_modules before website install to satisfy local path deps.
# We are currently in website/ (docusaurusRoot), so go up one level for root install.
cd ..
npm ci --ignore-scripts

# --- Install website monorepo (all workspaces) and build ---
cd website
npm ci
npm run -w docs build

echo "[DONE] Build complete."
