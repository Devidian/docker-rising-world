#!/usr/bin/env bash
set -Eeuo pipefail

readonly game_dir="${1:?game directory is required}"
readonly keep="${2:?retention count is required}"
readonly backup_dir="${game_dir}/Backups/docker-rising-world"
readonly repository="${backup_dir}/repository"

sources=()
for name in Worlds Plugins; do
    if [[ -d "${game_dir}/${name}" ]]; then
        sources+=("${name}")
    fi
done

if (( ${#sources[@]} == 0 )); then
    printf '%s\n' 'No Worlds or Plugins directory exists; skipping backup.'
    exit 0
fi

mkdir -p -- "${backup_dir}"
export BORG_PASSPHRASE=""
export BORG_CACHE_DIR="${backup_dir}/cache"
export BORG_SECURITY_DIR="${backup_dir}/security"

if [[ ! -e "${repository}" ]]; then
    borg init --encryption=authenticated "${repository}"
fi

timestamp="$(date -u +%Y%m%dT%H%M%S.%NZ)"
archive="rw-${timestamp}-${RANDOM}"
(
    cd -- "${game_dir}"
    borg create --compression lz4 "${repository}::${archive}" "${sources[@]}"
)
printf 'Backup created: %s::%s\n' "${repository}" "${archive}"

borg prune --glob-archives 'rw-*' --keep-last "${keep}" "${repository}"
borg compact --threshold 1 "${repository}"
