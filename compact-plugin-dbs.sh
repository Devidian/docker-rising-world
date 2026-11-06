#!/usr/bin/env bash
set -Eeuo pipefail

readonly game_dir="${1:?game directory is required}"
readonly enabled="${2:?enabled flag is required}"
readonly minimum_mib="${3:?minimum size is required}"
readonly backup_enabled="${4:?backup flag is required}"
readonly backup_keep="${5:?backup retention is required}"
readonly backup_script="${6:?backup script is required}"
readonly plugins_dir="${game_dir}/Plugins"
readonly minimum_bytes=$((minimum_mib * 1024 * 1024))

warn() {
    printf 'WARNING: Plugin database compaction: %s\n' "$*" >&2
}

cleanup_committed() {
    local marker="$1"
    rm -f -- "${marker}/original.db" "${marker}/original.db-wal" \
        "${marker}/original.db-shm" "${marker}/original.db-journal" \
        "${marker}/new.db" || return 1
    rm -f -- "${marker}/committed" || return 1
    rmdir -- "${marker}" || return 1
}

recover_one() {
    local marker="$1"
    local db="${marker%.rw-compact-rollback}"
    local suffix

    if [[ -e "${marker}/committed" ]]; then
        cleanup_committed "${marker}" || return 1
        return 0
    fi

    for suffix in '' '-wal' '-shm' '-journal'; do
        if [[ -e "${marker}/original.db${suffix}" ]]; then
            rm -f -- "${db}${suffix}" || return 1
            mv -- "${marker}/original.db${suffix}" "${db}${suffix}" || return 1
        fi
    done
    rm -f -- "${marker}/new.db" || return 1
    rmdir -- "${marker}" || return 1
}

# Recover interrupted swaps before making a new backup or opening any database.
if [[ -d "${plugins_dir}" ]]; then
    while IFS= read -r -d '' marker; do
        if ! recover_one "${marker}"; then
            printf 'ERROR: Could not recover interrupted database compaction at %s.\n' \
                "${marker}" >&2
            exit 74
        fi
    done < <(find "${plugins_dir}" -type d -name '*.db.rw-compact-rollback' -print0)
fi

candidates=()
if [[ "${enabled}" == true && -d "${plugins_dir}" ]]; then
    while IFS= read -r -d '' db; do
        if ! size="$(stat -c %s -- "${db}")"; then
            warn "could not read the size of ${db}; skipping this file."
            continue
        fi
        if (( size > minimum_bytes )); then
            candidates+=("${db}")
        fi
    done < <(find "${plugins_dir}" -type d -name '*.db.rw-compact-rollback' -prune \
        -o -type f -name '*.db' -print0)
fi

if [[ "${backup_enabled}" == true || ${#candidates[@]} -gt 0 ]]; then
    if ! "${backup_script}" "${game_dir}" "${backup_keep}"; then
        if [[ "${backup_enabled}" == true ]]; then
            printf 'ERROR: Startup backup failed.\n' >&2
            exit 74
        fi
        warn 'backup failed; skipping compaction and starting the server.'
        exit 0
    fi
fi

compact_one() {
    local db="$1"
    local marker="${db}.rw-compact-rollback"
    local output="${marker}/new.db"
    local sql_output
    local check
    local suffix

    if ! mkdir -- "${marker}"; then
        return 1
    fi

    # SQLite quotes file names inside VACUUM INTO using doubled apostrophes.
    sql_output="${output//\'/\'\'}"
    if ! sqlite3 -batch "${db}" "VACUUM INTO '${sql_output}';" ||
        ! check="$(sqlite3 -batch -noheader "${output}" 'PRAGMA quick_check;')" ||
        [[ "${check}" != ok ]] ||
        ! chmod --reference="${db}" "${output}"; then
        recover_one "${marker}" || return 2
        return 1
    fi

    for suffix in '' '-wal' '-shm' '-journal'; do
        if [[ -e "${db}${suffix}" ]] &&
            ! mv -- "${db}${suffix}" "${marker}/original.db${suffix}"; then
            recover_one "${marker}" || return 2
            return 1
        fi
    done

    if ! mv -- "${output}" "${db}" ||
        ! check="$(sqlite3 -batch -noheader "${db}" 'PRAGMA quick_check;')" ||
        [[ "${check}" != ok ]] ||
        ! touch -- "${marker}/committed"; then
        recover_one "${marker}" || return 2
        return 1
    fi

    if ! cleanup_committed "${marker}"; then
        warn "compacted ${db}, but could not remove its temporary rollback files."
    fi
}

for db in "${candidates[@]}"; do
    if ! before="$(stat -c %s -- "${db}")"; then
        warn "could not read the size of ${db}; skipping this file."
        continue
    fi
    if compact_one "${db}"; then
        after="$(stat -c %s -- "${db}")"
        printf 'Compacted plugin database %s: %s -> %s bytes.\n' \
            "${db}" "${before}" "${after}"
    else
        status=$?
        if (( status == 2 )); then
            printf 'ERROR: Could not restore %s after compaction failure.\n' "${db}" >&2
            exit 74
        fi
        warn "failed to compact ${db}; restored the original and starting the server."
    fi
done
