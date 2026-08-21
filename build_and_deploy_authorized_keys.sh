#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_DIR="$HOME/.ssh"
CHECK_ONLY=false
ASSUME_YES=false

usage() {
  cat <<'EOF'
Usage: ./build_and_deploy_authorized_keys.sh [--check | --yes]

  --check  Validate the repository and show the deployment plan only.
  --yes    Deploy without asking for confirmation.
EOF
}

case "${1:-}" in
  "") ;;
  --check) CHECK_ONLY=true ;;
  --yes) ASSUME_YES=true ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ ! -f "$REPO_DIR/config" || ! -d "$REPO_DIR/config.d" ]]; then
  echo "ERROR: config or config.d is missing from $REPO_DIR" >&2
  exit 1
fi

stage_dir="$(mktemp -d)"
trap 'rm -rf "$stage_dir"' EXIT
mkdir -p "$stage_dir/config.d"

cp "$REPO_DIR/config" "$stage_dir/config"
cp "$REPO_DIR"/config.d/*.conf "$stage_dir/config.d/"

shopt -s nullglob
pubkey_files=("$REPO_DIR"/*.id_ed25519.pub)
shopt -u nullglob

if [[ ${#pubkey_files[@]} -eq 0 ]]; then
  echo "ERROR: no top-level Ed25519 public keys found." >&2
  exit 1
fi

for pubkey_file in "${pubkey_files[@]}"; do
  if ! awk '
    NF { count++; if ($1 != "ssh-ed25519") invalid = 1 }
    END { exit !(count == 1 && !invalid) }
  ' "$pubkey_file"; then
    echo "ERROR: expected one Ed25519 public key in $pubkey_file" >&2
    exit 1
  fi
  ssh-keygen -l -f "$pubkey_file" >/dev/null
done

cat "${pubkey_files[@]}" \
  | awk 'NF > 0' \
  | LC_ALL=C sort -u > "$stage_dir/authorized_keys"

# Validate the Include layout without depending on the current ~/.ssh files.
sed "s|~/.ssh/config.d|$stage_dir/config.d|g" \
  "$stage_dir/config" > "$stage_dir/config.validation"

while IFS= read -r host; do
  ssh -T -G -F "$stage_dir/config.validation" "$host" >/dev/null
done < <(
  awk '$1 == "Host" { for (i = 2; i <= NF; i++) if ($i != "*") print $i }' \
    "$stage_dir"/config.d/*.conf \
    | LC_ALL=C sort -u
)

key_count="$(grep -c '^ssh-ed25519 ' "$stage_dir/authorized_keys" || true)"

echo "Validation passed."
echo "Ed25519 public keys: $key_count"
echo
echo "Deployment plan:"
echo "  $REPO_DIR/config          -> $SSH_DIR/config"
echo "  $REPO_DIR/config.d/*.conf -> $SSH_DIR/config.d/"
echo "  generated public keys     -> $SSH_DIR/authorized_keys"
echo
echo "Existing destination files will be backed up before replacement."

if [[ "$CHECK_ONLY" == true ]]; then
  exit 0
fi

if [[ "$ASSUME_YES" != true ]]; then
  read -r -p "Deploy all SSH files? [y/N] " answer
  case "$answer" in
    y|Y) ;;
    *)
      echo "Skipped deploy."
      exit 0
      ;;
  esac
fi

mkdir -p "$SSH_DIR/config.d"
chmod 700 "$SSH_DIR" "$SSH_DIR/config.d"

backup_dir=""
backup_existing_file() {
  local source_file="$1"
  local relative_path="$2"

  [[ -e "$source_file" ]] || return 0

  if [[ -z "$backup_dir" ]]; then
    backup_dir="$SSH_DIR/backups/config_ssh/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    chmod 700 "$SSH_DIR/backups" "$SSH_DIR/backups/config_ssh" "$backup_dir"
  fi

  mkdir -p "$backup_dir/$(dirname "$relative_path")"
  cp -p "$source_file" "$backup_dir/$relative_path"
}

backup_existing_file "$SSH_DIR/config" "config"
backup_existing_file "$SSH_DIR/authorized_keys" "authorized_keys"
for config_file in "$stage_dir"/config.d/*.conf; do
  config_name="$(basename "$config_file")"
  backup_existing_file "$SSH_DIR/config.d/$config_name" "config.d/$config_name"
done

install -m 600 "$stage_dir/config" "$SSH_DIR/config"
for config_file in "$stage_dir"/config.d/*.conf; do
  install -m 600 "$config_file" "$SSH_DIR/config.d/$(basename "$config_file")"
done
install -m 600 "$stage_dir/authorized_keys" "$SSH_DIR/authorized_keys"

if [[ -n "$backup_dir" ]]; then
  echo "Backup: $backup_dir"
fi
echo "Deployment completed."
