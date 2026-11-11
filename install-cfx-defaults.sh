#!/usr/bin/env bash
# Installs only the standard CFX resources required by server.cfg.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_ROOT="${FXSERVER_RESOURCES_DIR:-$SCRIPT_DIR/resources}"
TARGET_DIR="$RESOURCE_ROOT/[cfx-default]"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! command -v git >/dev/null 2>&1; then
    echo "ERREUR: git est requis pour télécharger cfx-server-data."
    exit 1
fi

mkdir -p "$TARGET_DIR"
echo "Téléchargement des ressources officielles depuis citizenfx/cfx-server-data..."
git clone --depth 1 https://github.com/citizenfx/cfx-server-data.git "$TMP_DIR/cfx-server-data" >/dev/null

SOURCE_DIR="$TMP_DIR/cfx-server-data/resources/[cfx-default]"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERREUR: dossier [cfx-default] introuvable dans cfx-server-data."
    exit 1
fi

for resource in spawnmanager sessionmanager hardcap baseevents; do
    if [ -f "$TARGET_DIR/$resource/fxmanifest.lua" ]; then
        echo "Déjà installé, conservé: $resource"
        continue
    fi
    if [ ! -f "$SOURCE_DIR/$resource/fxmanifest.lua" ]; then
        echo "ERREUR: $resource absent du dépôt officiel téléchargé."
        exit 1
    fi
    cp -a "$SOURCE_DIR/$resource" "$TARGET_DIR/$resource"
    echo "Installé: $resource"
done

echo "Ressources CFX standard prêtes dans: $TARGET_DIR"
