#!/bin/bash
# Sync code from CloudSound repo into each microservice repo and help push to GitHub.
# Workflows (.github/workflows/build-and-push-azure.yml) only appear on GitHub after you push.
#
# Usage:
#   ./scripts/sync-and-push-service-repos.sh              # sync code, then show push instructions
#   ./scripts/sync-and-push-service-repos.sh --sync-only  # only sync, no git instructions
#   ./scripts/sync-and-push-service-repos.sh --push       # sync, then git add + commit + push in each repo (prompts for message)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUDSOUND_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$CLOUDSOUND_ROOT")"

SERVICES="api-gateway authentication radio-streaming concert-management analytics music-discovery event-manager admin-management"
SYNC_ONLY=false
DO_PUSH=false

for arg in "$@"; do
  case "$arg" in
    --sync-only) SYNC_ONLY=true ;;
    --push)      DO_PUSH=true ;;
  esac
done

echo "=== Syncing code from CloudSound to each service repo ==="
for svc in $SERVICES; do
  SRC="${CLOUDSOUND_ROOT}/backend/${svc}"
  DST="${WORKSPACE_ROOT}/cloudsound-${svc}"
  if [ ! -d "$SRC" ]; then
    echo "  Skip $svc (no backend/$svc)"
    continue
  fi
  if [ ! -d "$DST" ]; then
    echo "  Skip $svc (no cloudsound-$svc at $DST)"
    continue
  fi
  echo "  Syncing $svc..."
  rsync -a --exclude='.git' --exclude='.github' "$SRC/" "$DST/"
done

echo ""
echo "=== Workflows and code are now in sync locally ==="

if [ "$SYNC_ONLY" = true ]; then
  echo "Done (--sync-only). To push to GitHub, run this script without --sync-only and follow the instructions."
  exit 0
fi

echo ""
echo "Workflows will NOT appear on GitHub until you push each repo."
echo ""
echo "For each repo, run:"
echo "  cd <workspace>/cloudsound-<service>"
echo "  git add -A"
echo "  git status   # check .github/workflows/build-and-push-azure.yml and synced files"
echo "  git commit -m 'Add ACR build workflow and sync code from CloudSound'"
echo "  git push origin main"
echo ""

if [ "$DO_PUSH" = true ]; then
  echo "=== Committing and pushing each repo (--push) ==="
  for svc in $SERVICES; do
    DST="${WORKSPACE_ROOT}/cloudsound-${svc}"
    [ ! -d "$DST" ] && continue
    echo "  cloudsound-$svc..."
    ( cd "$DST" && git add -A && git status -sb )
    read -p "  Commit and push cloudsound-$svc? [y/N] " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      ( cd "$DST" && git commit -m "Add ACR build workflow and sync code from CloudSound" && git push origin main )
    fi
  done
  echo "Done."
else
  echo "To have this script prompt to commit and push each repo, run:"
  echo "  ./scripts/sync-and-push-service-repos.sh --push"
fi
