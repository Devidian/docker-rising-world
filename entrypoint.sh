#!/usr/bin/env bash
set -Eeuo pipefail

readonly GAME_DIR="/appdata/rising-world/dedicated-server"
readonly GAME_ID="339010"
readonly SERVER_BINARY="${GAME_DIR}/RisingWorldServer.x64"
readonly STEAMCMD="/home/steam/steamcmd/steamcmd.sh"
readonly PLUGINS_DIR="${GAME_DIR}/Plugins"
readonly OZ_TOOLS_DIR="${PLUGINS_DIR}/OZTools"
readonly OZ_TOOLS_RELEASE_API="https://api.github.com/repos/Devidian/rw-plugin-oz-tools/releases/latest"

RW_UPDATE_ON_START="${RW_UPDATE_ON_START:-true}"
RW_VALIDATE="${RW_VALIDATE:-false}"
RW_INSTALL_OZ_TOOLS="${RW_INSTALL_OZ_TOOLS:-false}"
readonly RW_UPDATE_ON_START
readonly RW_VALIDATE
readonly RW_INSTALL_OZ_TOOLS

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

cleanup_oz_tools_update() {
    local archive="$1"
    local stage_dir="$2"

    if [[ -n "${archive}" && -e "${archive}" ]]; then
        rm -f -- "${archive}" || true
    fi

    if [[ -n "${stage_dir}" && -d "${stage_dir}" ]]; then
        rm -rf -- "${stage_dir}" || true
    fi
}

install_oz_tools() {
    local archive=""
    local backup_dir="${PLUGINS_DIR}/.oztools-backup.$$"
    local download_url
    local download_urls
    local release_json
    local stage_dir=""

    if ! mkdir -p "${PLUGINS_DIR}"; then
        return 1
    fi

    if ! archive="$(mktemp "${TMPDIR:-/tmp}/oztools.XXXXXX.zip")"; then
        return 1
    fi

    if ! release_json="$(curl --fail --silent --show-error --location \
        "${OZ_TOOLS_RELEASE_API}")"; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    if ! download_urls="$(printf '%s\n' "${release_json}" |
        sed -n 's/.*"browser_download_url": "\([^"]*\.zip\)".*/\1/p')"; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    download_url="${download_urls%%$'\n'*}"
    if [[ -z "${download_url}" ]]; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    printf 'Downloading latest OZ Tools release from %s...\n' "${download_url}"
    if ! curl --fail --silent --show-error --location \
        "${download_url}" --output "${archive}"; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    if ! stage_dir="$(mktemp -d "${PLUGINS_DIR}/.oztools-install.XXXXXX")"; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    if [[ -e "${OZ_TOOLS_DIR}" && ! -d "${OZ_TOOLS_DIR}" ]]; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    if ! mkdir -p "${stage_dir}/OZTools"; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    if [[ -d "${OZ_TOOLS_DIR}" ]] &&
        ! cp -a "${OZ_TOOLS_DIR}/." "${stage_dir}/OZTools/"; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    if ! unzip -oq "${archive}" -d "${stage_dir}" ||
        [[ ! -f "${stage_dir}/OZTools/OZTools.jar" ]]; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    if [[ -e "${backup_dir}" ]]; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    if [[ -d "${OZ_TOOLS_DIR}" ]] && ! mv "${OZ_TOOLS_DIR}" "${backup_dir}"; then
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    if ! mv "${stage_dir}/OZTools" "${OZ_TOOLS_DIR}"; then
        if [[ -d "${backup_dir}" ]]; then
            mv "${backup_dir}" "${OZ_TOOLS_DIR}" || true
        fi
        cleanup_oz_tools_update "${archive}" "${stage_dir}"
        return 1
    fi

    cleanup_oz_tools_update "${archive}" "${stage_dir}"
    if [[ -d "${backup_dir}" ]]; then
        rm -rf -- "${backup_dir}" || true
    fi

    return 0
}

validate_boolean "RW_UPDATE_ON_START" "${RW_UPDATE_ON_START}"
validate_boolean "RW_VALIDATE" "${RW_VALIDATE}"
validate_boolean "RW_INSTALL_OZ_TOOLS" "${RW_INSTALL_OZ_TOOLS}"

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

if [[ "${RW_INSTALL_OZ_TOOLS}" == "true" ]]; then
    if install_oz_tools; then
        printf '%s\n' "OZ Tools installation completed."
    else
        printf '%s\n' \
            "WARNING: OZ Tools installation failed; starting the server anyway." >&2
    fi
fi

export LD_LIBRARY_PATH="${GAME_DIR}/linux64:${GAME_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

printf '%s\n' "Starting Rising World dedicated server..."
exec "${SERVER_BINARY}"
