#!/usr/bin/env bash
set -euo pipefail

INBOX="$HOME/csce465-hw3/inbox"
PARSER="$HOME/csce465-hw3/legacy_log_parser"

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s FILE\n' "$0" >&2
    exit 1
fi

inbox=$(realpath -e -- "$INBOX")
input=$(realpath -e -- "$1")

if [[ "$input" != "$inbox/"* || ! -f "$input" || ! -r "$input" ]]; then
    printf 'Input must be a readable file inside %s\n' "$inbox" >&2
    exit 1
fi

exec "$PARSER" "$input"
