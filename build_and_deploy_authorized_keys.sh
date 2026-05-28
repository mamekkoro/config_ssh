#!/usr/bin/env bash
set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_DIR="$HOME/.ssh"
TOBE_FILE="$SSH_DIR/authorized_keys.tobe"
AUTH_FILE="$SSH_DIR/authorized_keys"

if [[ ! -d "$SSH_DIR" ]]; then
  echo "ERROR: $SSH_DIR does not exist." >&2
  exit 1
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

find "$REPO_DIR" -maxdepth 1 -type f -name '*.id_ed25519.pub' -print0 \
  | sort -z \
  | xargs -0 cat \
  | awk 'NF > 0' \
  | sort -u > "$tmp_file"

mv "$tmp_file" "$TOBE_FILE"
chmod 600 "$TOBE_FILE"

echo "Wrote: $TOBE_FILE"
echo "Included keys: $(grep -c '^ssh-ed25519 ' "$TOBE_FILE" || true)"
echo

read -r -p "Deploy $TOBE_FILE to $AUTH_FILE ? [y/N] " answer

case "$answer" in
  y|Y)
    if [[ -e "$AUTH_FILE" ]]; then
      backup="${AUTH_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
      cp -a "$AUTH_FILE" "$backup"
      echo "Backup: $backup"
    fi

    cp -a "$TOBE_FILE" "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
    echo "Deployed: $AUTH_FILE"
    ;;
  *)
    echo "Skipped deploy."
    ;;
esac


