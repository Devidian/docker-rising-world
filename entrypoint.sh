#!/usr/bin/env bash
set -Eeuo pipefail

readonly GAME_DIR="/appdata/rising-world/dedicated-server"
readonly GAME_ID="339010"
readonly SERVER_BINARY="${GAME_DIR}/RisingWorldServer.x64"
readonly STEAMCMD="/home/steam/steamcmd/steamcmd.sh"

RW_UPDATE_ON_START="${RW_UPDATE_ON_START:-true}"
RW_VALIDATE="${RW_VALIDATE:-false}"
readonly RW_UPDATE_ON_START
readonly RW_VALIDATE

validate_boolean() {
    local name="$1"
    local value="$2"

    case "${value}" in
        true|false)
            ;;
        *)
            printf 'ERROR: %s must be either "true" or "false" (received: %s).\n' \
                "${name}" "${value}" >&2
            exit 64
            ;;
    esac
}

validate_boolean "RW_UPDATE_ON_START" "${RW_UPDATE_ON_START}"
validate_boolean "RW_VALIDATE" "${RW_VALIDATE}"

mkdir -p "${GAME_DIR}"

if [[ ! -w "${GAME_DIR}" ]]; then
    printf 'ERROR: %s is not writable by uid=%s gid=%s.\n' \
        "${GAME_DIR}" "$(id -u)" "$(id -g)" >&2
    printf 'For bind mounts, assign the directory to uid 1000 and gid 1000 before starting the container.\n' >&2
    exit 73
fi

if [[ ! -x "${STEAMCMD}" ]]; then
    printf 'ERROR: SteamCMD is not executable at %s.\n' "${STEAMCMD}" >&2
    exit 69
fi

if [[ "${RW_UPDATE_ON_START}" == "true" || ! -x "${SERVER_BINARY}" ]]; then
    steamcmd_args=(
        +force_install_dir "${GAME_DIR}"
        +login anonymous
        +app_info_update 1
        +app_update "${GAME_ID}"
    )

    if [[ "${RW_VALIDATE}" == "true" ]]; then
        steamcmd_args+=(validate)
    fi

    steamcmd_args+=(+quit)

    printf '%s\n' "Updating Rising World dedicated server..."
    "${STEAMCMD}" "${steamcmd_args[@]}"
else
    printf '%s\n' "Skipping Rising World dedicated server update."
fi

if [[ ! -x "${SERVER_BINARY}" ]]; then
    printf 'ERROR: Server executable is missing or not executable at %s.\n' \
        "${SERVER_BINARY}" >&2
    exit 69
fi

export LD_LIBRARY_PATH="${GAME_DIR}/linux64:${GAME_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

printf '%s\n' "Starting Rising World dedicated server..."
exec "${SERVER_BINARY}"
