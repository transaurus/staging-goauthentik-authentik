#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/goauthentik/authentik"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Node 24 setup ---
# Docusaurus 3.9.2 in website/docs/ requires Node 24+
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

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# --- Install repo root dependencies ---
# Required because website/package.json preinstall runs: npm ci --prefix ..
# And website/docs has local path deps on shared packages
npm ci --ignore-scripts

# --- Install website monorepo (all workspaces) ---
cd website
npm ci

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

echo "[DONE] Repository is ready for docusaurus commands."
