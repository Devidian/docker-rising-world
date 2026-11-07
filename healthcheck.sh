#!/usr/bin/env bash
set -Eeuo pipefail

# Rising World serves /info on the port immediately below Server_Port.
game_port=4255
if [[ -f server.properties ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%$'\r'}"
        if [[ "${line}" =~ ^[[:space:]]*Server_Port[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            value="${BASH_REMATCH[1]}"
            value="${value%"${value##*[![:space:]]}"}"
            if [[ ! "${value}" =~ ^[0-9]{1,5}$ ]]; then
                printf 'Invalid Server_Port in server.properties: %s\n' "${value}" >&2
                exit 1
            fi
            game_port=$((10#${value}))
            break
        fi
    done < server.properties
fi

if (( game_port < 2 || game_port > 65535 )); then
    printf 'Server_Port must be between 2 and 65535: %s\n' "${game_port}" >&2
    exit 1
fi

curl --fail --silent --show-error --max-time 4 \
    "http://127.0.0.1:$((game_port - 1))/info" > /dev/null
