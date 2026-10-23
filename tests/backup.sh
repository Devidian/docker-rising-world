#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_dir
test_dir="$(mktemp -d)"
trap 'rm -rf -- "${test_dir}"' EXIT

game_dir="${test_dir}/game"
mkdir -p "${game_dir}/Worlds/New World" "${game_dir}/Plugins/OZTools"
printf 'world-v1\n' > "${game_dir}/Worlds/New World/Player.db"
printf 'plugin-v1\n' > "${game_dir}/Plugins/OZTools/settings.json"

bash "${repo_dir}/backup.sh" "${game_dir}" 2
backup_dir="${game_dir}/Backups/docker-rising-world"
repository="${backup_dir}/repository"
export BORG_PASSPHRASE="" BORG_CACHE_DIR="${backup_dir}/cache"
export BORG_SECURITY_DIR="${backup_dir}/security"
mapfile -t archives < <(borg list --short "${repository}")
[[ "${#archives[@]}" -eq 1 ]]
[[ "$(borg extract --stdout "${repository}::${archives[0]}" 'Worlds/New World/Player.db')" == world-v1 ]]
[[ "$(borg extract --stdout "${repository}::${archives[0]}" 'Plugins/OZTools/settings.json')" == plugin-v1 ]]

printf 'world-v2\n' > "${game_dir}/Worlds/New World/Player.db"
bash "${repo_dir}/backup.sh" "${game_dir}" 2
printf 'world-v3\n' > "${game_dir}/Worlds/New World/Player.db"
bash "${repo_dir}/backup.sh" "${game_dir}" 2

mapfile -t archives < <(borg list --short "${repository}")
[[ "${#archives[@]}" -eq 2 ]]
[[ "$(borg extract --stdout "${repository}::${archives[0]}" 'Worlds/New World/Player.db')" == world-v2 ]]
[[ "$(borg extract --stdout "${repository}::${archives[1]}" 'Worlds/New World/Player.db')" == world-v3 ]]
[[ "$(borg extract --stdout "${repository}::${archives[1]}" 'Plugins/OZTools/settings.json')" == plugin-v1 ]]

empty_dir="${test_dir}/empty"
mkdir -p "${empty_dir}"
bash "${repo_dir}/backup.sh" "${empty_dir}" 2
[[ ! -e "${empty_dir}/Backups" ]]
