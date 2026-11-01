#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s FILE\n' "$0" >&2
    exit 1
fi

inbox=$(realpath -e -- "$HOME/csce465-hw3/inbox")
input=$(realpath -e -- "$1")

if [[ "$input" != "$inbox/"* || ! -f "$input" || ! -r "$input" ]]; then
    printf 'Input must be a readable file inside %s\n' "$inbox" >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$script_dir/../../legacy_log_parser" "$input"
