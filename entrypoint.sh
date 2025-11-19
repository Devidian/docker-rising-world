#!/bin/bash
GAME_DIR="/appdata/rising-world/dedicated-server"
CONFIG_PATH="${GAME_DIR}/server.properties"
GAME_ID=339010

mkdir -p ${GAME_DIR}
chown -R steam:steam ${GAME_DIR}

while true; do
    echo "-------------------------------START------------------------------"
    su -c "~/steamcmd/steamcmd.sh +force_install_dir ${GAME_DIR} +login anonymous +app_update ${GAME_ID} validate +quit" steam

    cd ${GAME_DIR}
    export LD_LIBRARY_PATH="${GAME_DIR}/linux64:${GAME_DIR}:$LD_LIBRARY_PATH"

    ./RisingWorldServer.x64

    echo "--------------------------------END-------------------------------"
    echo "Server exited, restarting in 5 seconds..."
    sleep 5
done
