#!/usr/bin/env bash
# FiveM Server Start Script (Linux)
set -e

echo "=== Démarrage du Serveur FiveM GTA 5 Roleplay ==="
echo "50 Métiers | Économie | Création de Personnage | Loadscreen | Tablette Admin"

SERVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SERVER_DIR"

if [ ! -f "server.cfg" ]; then
    echo "ERREUR: server.cfg introuvable!"
    exit 1
fi

if [ -z "$FXSERVER_PATH" ]; then
    FXSERVER_PATH="/opt/cfx-server"
fi

if [ -f "$FXSERVER_PATH/run.sh" ]; then
    echo "Lancement avec FXServer: $FXSERVER_PATH/run.sh"
    exec "$FXSERVER_PATH/run.sh" +exec server.cfg
else
    echo "Notice: FXSERVER_PATH ($FXSERVER_PATH) non présent localement. Assurez-vous d'avoir installé les artifacts FiveM."
    echo "Pour lancer manuellement : /chemin/vers/fxserver/run.sh +exec server.cfg"
fi
